package pe.platter.shared.storage;

import java.net.URI;
import java.util.Optional;

import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

import pe.platter.shared.config.PlatterProperties;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;

/** Adaptador de {@link ObjectStorage} para cualquier servicio compatible con S3 (CON-04). */
@Component
@ConditionalOnExpression("!'${platter.storage.s3.bucket:}'.isBlank()")
class S3ObjectStorage implements ObjectStorage {

    private final S3Client s3;
    private final String bucket;

    S3ObjectStorage(PlatterProperties properties) {
        PlatterProperties.S3 config = properties.storage().s3();
        this.bucket = config.bucket();
        S3ClientBuilder builder = S3Client.builder()
                .region(Region.of(config.region()))
                .httpClient(UrlConnectionHttpClient.create())
                .forcePathStyle(true)
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(config.accessKey(), config.secretKey())));
        if (config.endpoint() != null && !config.endpoint().isBlank()) {
            builder.endpointOverride(URI.create(config.endpoint()));
        }
        this.s3 = builder.build();
    }

    @Override
    public void put(String key, byte[] content) {
        s3.putObject(r -> r.bucket(bucket).key(key), RequestBody.fromBytes(content));
    }

    @Override
    public Optional<byte[]> get(String key) {
        try {
            return Optional.of(s3.getObjectAsBytes(r -> r.bucket(bucket).key(key)).asByteArray());
        } catch (NoSuchKeyException e) {
            return Optional.empty();
        }
    }
}
