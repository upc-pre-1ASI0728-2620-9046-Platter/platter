package pe.platter.shared.storage;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;

import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

import pe.platter.shared.config.PlatterProperties;

@Component
@ConditionalOnExpression("'${platter.storage.s3.bucket:}'.isBlank()")
class LocalObjectStorage implements ObjectStorage {

    private final Path root;

    LocalObjectStorage(PlatterProperties properties) {
        this.root = properties.storage().localDir().toAbsolutePath().normalize();
    }

    @Override
    public void put(String key, byte[] content) {
        Path target = resolve(key);
        try {
            Files.createDirectories(target.getParent());
            Files.write(target, content);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @Override
    public Optional<byte[]> get(String key) {
        Path target = resolve(key);
        if (!Files.isRegularFile(target)) {
            return Optional.empty();
        }
        try {
            return Optional.of(Files.readAllBytes(target));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private Path resolve(String key) {
        Path target = root.resolve(key).normalize();
        if (!target.startsWith(root)) {
            throw new IllegalArgumentException("Clave de almacenamiento inválida");
        }
        return target;
    }
}
