package io.github.springstudent.dekstop.client.squeeze;


import io.github.springstudent.dekstop.client.bean.Capture;
import io.github.springstudent.dekstop.client.bean.CaptureTile;
import io.github.springstudent.dekstop.common.bean.CompressionMethod;
import io.github.springstudent.dekstop.common.bean.MemByteBuffer;
import io.github.springstudent.dekstop.common.log.Log;

import java.awt.*;
import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;

/**
 * 压缩/解压器，支持多种压缩算法
 * 单例模式，根据压缩方法返回对应的压缩器实例
 */
public final class Compressor {
    /**
     * 无压缩（仅用于测试）
     */
    private static final Compressor NULL_COMPRESSOR = new Compressor(CompressionMethod.NONE, new NullRunLengthEncoder(), new NullZipper());

    /**
     * ZIP压缩（带常规行程长度编码）
     */
    private static final Compressor ZIP_COMPRESSOR = new Compressor(CompressionMethod.ZIP, new RegularRunLengthEncoder(), new ZipZipper());

    /**
     * XZ压缩
     */
    private static final Compressor XZ_COMPRESSOR = new Compressor(CompressionMethod.XZ, new NullRunLengthEncoder(), new XzZipper());

    /**
     * ZSTD压缩
     */
    private static final Compressor ZSTD_COMPRESSOR = new Compressor(CompressionMethod.ZSTD, new NullRunLengthEncoder(), new ZstdZipper());

    // 压缩方法
    private final CompressionMethod method;

    // 行程长度编码器
    private final RunLengthEncoder rle;

    // 压缩/解压器
    private final Zipper zipper;

    /**
     * 私有构造函数
     * @param method 压缩方法
     * @param rle 行程长度编码器
     * @param zipper 压缩/解压器
     */
    private Compressor(CompressionMethod method, RunLengthEncoder rle, Zipper zipper) {
        this.method = method;
        this.rle = rle;
        this.zipper = zipper;
    }

    /**
     * 获取对应压缩方法的压缩器实例
     * @param method 压缩方法
     * @return 压缩器实例
     */
    public static Compressor get(CompressionMethod method) {

        switch (method) {
            case ZIP:
                return ZIP_COMPRESSOR;
            case XZ:
                return XZ_COMPRESSOR;
            case ZSTD:
                return ZSTD_COMPRESSOR;
            case NONE:
                return NULL_COMPRESSOR;
            default:
                throw new IllegalArgumentException("Unsupported compressor configuration [" + method + "]!");
        }

    }

    /**
     * 获取压缩方法
     * @return 压缩方法
     */
    public CompressionMethod getMethod() {
        return method;
    }

    /**
     * 压缩捕获数据
     * @param cache 瓦片缓存
     * @param capture 捕获对象
     * @return 压缩后的字节缓冲区
     * @throws IOException IO异常
     */
    public MemByteBuffer compress(TileCache cache, Capture capture) throws IOException {
        final MemByteBuffer encoded = new MemByteBuffer();
        // 写入元数据
        encoded.writeInt(capture.getId());
        encoded.write(capture.isReset() ? 1 : 0);
        encoded.write(capture.getSkipped()); // 作为字节写入
        encoded.write(capture.getMerged()); // 作为字节写入
        
        // 如果需要重置，则清空缓存
        if (capture.isReset()) {
            Log.debug("Clear compressor cache [tile:" + capture.getId() + "]");
            cache.clear(); // 与解压端保持对称
        }
        
        // 写入尺寸信息
        encoded.writeShort(capture.getWidth());
        encoded.writeShort(capture.getHeight());
        encoded.writeShort(capture.getTWidth());
        encoded.writeShort(capture.getTHeight());
        
        // 处理瓦片数据
        final CaptureTile[] tiles = capture.getDirtyTiles();
        int idx = 0;
        while (idx < tiles.length) {
            // 计算连续瓦片数量
            final int markerCount = computeMarkerCount(tiles, idx);
            if (markerCount > 0) {
                // 写入连续非空瓦片数量
                encoded.write(markerCount);
                // 编码每个瓦片
                for (int tidx = idx; tidx < idx + markerCount; tidx++) {
                    encodeTile(cache, rle, encoded, tiles[tidx]);
                }
                idx += markerCount;
            } else {
                // 写入连续空瓦片数量
                encoded.write(markerCount);
                idx += (-markerCount + 1);
            }
        }
        
        // 执行压缩
        return zipper.zip(encoded);
    }

    /**
     * 计算连续瓦片数量
     * <pre>
     * [    1 .. 127 ] : N个非空瓦片
     * [ -128 .. 0   ] : (-N+1)个空瓦片
     * </pre>
     * @param tiles 瓦片数组
     * @param from 起始索引
     * @return 连续瓦片数量
     */
    private static int computeMarkerCount(CaptureTile[] tiles, int from) {
        final CaptureTile tile = tiles[from++];
        if (tile == null) {
            // 计算连续空瓦片数量
            int count = 0;
            while (count < 128 && from < tiles.length && tiles[from++] == null) {
                ++count;
            }
            return -count;
        }
        // 计算连续非空瓦片数量
        int count = 1;
        while (count < 127 && from < tiles.length && tiles[from++] != null) {
            ++count;
        }
        return count;
    }

    /**
     * 编码瓦片数据
     * @param cache 瓦片缓存
     * @param encoder 行程长度编码器
     * @param encoded 编码后的字节缓冲区
     * @param tile 瓦片对象
     */
    private static void encodeTile(TileCache cache, RunLengthEncoder encoder, MemByteBuffer encoded, CaptureTile tile) {
        // 单级瓦片 : [ 0 .. 256 [
        if (tile.getSingleLevel() != -1) {
            encoded.writeShort(tile.getSingleLevel() & 0xFF);
            return;
        }
        // 多级瓦片 : 缓存的 [256]
        final int cacheId = cache.getCacheId(tile);
        if (cache.get(cacheId) != CaptureTile.MISSING) // LRU使用
        {
            encoded.writeShort(256);
            encoded.writeInt(cacheId);
            return;
        }
        // 多级瓦片 (未缓存) [ -32768 .. 0 [
        final int mark = encoded.mark();
        encoded.writeShort(42); // 临时值，后续会被替换
        encoder.runLengthEncode(encoded, tile.getCapture());
        encoded.writeLenAsShort(mark);
        cache.add(tile);
    }

    /**
     * 解压捕获数据
     * @param cache 瓦片缓存
     * @param zipped 压缩的字节缓冲区
     * @return 解压后的捕获对象
     * @throws IOException IO异常
     */
    public Capture decompress(TileCache cache, MemByteBuffer zipped) throws IOException {
        // 1. 解压数据
        final MemByteBuffer unzipped = zipper.unzip(zipped);
        final DataInputStream in = new DataInputStream(new ByteArrayInputStream(unzipped.getInternal(), 0, unzipped.size()));
        
        // 2. 读取元数据
        final int cId = in.readInt();
        final boolean cReset = in.read() == 1;
        if (cReset) {
            Log.debug("Clear de-compressor cache [tile:" + cId + "]");
            cache.clear();
        }
        final int cSkipped = in.readUnsignedByte();
        final int cMerged = in.readUnsignedByte();
        
        // 3. 读取尺寸信息
        final Dimension captureDimension = new Dimension(in.readShort(), in.readShort());
        final Dimension tileDimension = new Dimension(in.readShort(), in.readShort());
        
        // 4. 计算瓦片布局
        final CaptureTile.XYWH[] xywh = CaptureTile.getXYWH(captureDimension.width, captureDimension.height, tileDimension.width, tileDimension.height);
        final CaptureTile[] dirty = new CaptureTile[xywh.length];
        
        // 5. 处理瓦片数据
        int idx = 0;
        while (idx < dirty.length) {
            final int markerCount = in.readByte();
            if (markerCount > 0) // 非空瓦片
            {
                for (int tidx = idx; tidx < idx + markerCount; tidx++) {
                    final int value = in.readShort();
                    if (value >= 0 && value < 256) // 单级瓦片
                    {
                        dirty[tidx] = new CaptureTile(xywh[tidx], (byte) value);
                    } else if (value == 256) // 多级瓦片（缓存）
                    {
                        dirty[tidx] = new CaptureTile(xywh[tidx], cache.get(in.readInt()));
                    } else // 多级瓦片（未缓存）
                    {
                        processUncached(cache, in, xywh[tidx], dirty, tidx, value);
                    }
                }
                idx += markerCount;
            } else // 空瓦片
            {
                idx += (-markerCount + 1);
            }
        }
        
        // 6. 创建并返回捕获对象
        return new Capture(cId, cReset, cSkipped, cMerged, captureDimension, tileDimension, dirty);
    }

    /**
     * 处理未缓存的瓦片数据
     * @param cache 瓦片缓存
     * @param in 数据输入流
     * @param xywh 瓦片位置和大小
     * @param dirty 瓦片数组
     * @param tidx 当前瓦片索引
     * @param value 瓦片数据长度信息（负数）
     * @throws IOException IO异常
     */
    private void processUncached(TileCache cache, DataInputStream in, CaptureTile.XYWH xywh, CaptureTile[] dirty, int tidx, int value) throws IOException {
        // 计算数据长度（value是负数，取其绝对值）
        final byte[] tdata = new byte[-value];
        int toffset = 0;
        int tcount;
        // 读取所有数据
        while ((tcount = in.read(tdata, toffset, tdata.length - toffset)) > 0) {
            toffset += tcount;
        }
        // 行程长度解码
        final MemByteBuffer out = new MemByteBuffer();
        rle.runLengthDecode(out, new MemByteBuffer(tdata));
        // 创建瓦片并添加到缓存
        dirty[tidx] = new CaptureTile(xywh, out);
        cache.add(dirty[tidx]);
    }
}