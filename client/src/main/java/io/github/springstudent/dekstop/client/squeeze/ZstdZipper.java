package io.github.springstudent.dekstop.client.squeeze;

import com.github.luben.zstd.ZstdInputStream;
import com.github.luben.zstd.ZstdCompressCtx;
import io.github.springstudent.dekstop.common.bean.MemByteBuffer;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Arrays;

/**
 * @author ZhouNing
 * @date 2025/2/19 10:02
 **/
public class ZstdZipper implements Zipper {
    @Override
    public MemByteBuffer zip(MemByteBuffer unzipped) throws IOException {
        byte[] rawData = Arrays.copyOf(unzipped.getInternal(), unzipped.size());
        ZstdCompressCtx ctx = new ZstdCompressCtx();
        ctx.setContentSize(true);
        byte[] compressed = ctx.compress(rawData);
        ctx.close();
        MemByteBuffer zipped = new MemByteBuffer();
        zipped.write(compressed);
        return zipped;
    }

    @Override
    public MemByteBuffer unzip(MemByteBuffer zipped) throws IOException {
        try (final MemByteBuffer unzipped = new MemByteBuffer()) {
            try (ZstdInputStream zstdInputStream = new ZstdInputStream(new ByteArrayInputStream(zipped.getInternal(), 0, zipped.size()))) {
                byte[] buffer = new byte[4096];
                int bytesRead;
                while ((bytesRead = zstdInputStream.read(buffer)) > 0) {
                    unzipped.write(buffer, 0, bytesRead);
                }
            }
            return unzipped;
        }
    }
}
