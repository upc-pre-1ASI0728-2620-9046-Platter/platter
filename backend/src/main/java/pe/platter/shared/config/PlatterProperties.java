package pe.platter.shared.config;

import java.nio.file.Path;
import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

@ConfigurationProperties("platter")
public record PlatterProperties(
        @DefaultValue("http://localhost:8081") String publicWebUrl,
        @DefaultValue Jwt jwt,
        @DefaultValue Storage storage,
        @DefaultValue Ai ai,
        @DefaultValue Demo demo) {

    public record Jwt(
            @DefaultValue("change-me-please-this-is-a-dev-only-secret-32b") String secret,
            @DefaultValue("1h") Duration ttl) {
    }

    public record Storage(@DefaultValue("./data/storage") Path localDir, @DefaultValue S3 s3) {
    }

    /** Si {@code bucket} tiene valor se usa almacenamiento S3 compatible en lugar del disco local. */
    public record S3(String bucket, String endpoint, @DefaultValue("us-east-1") String region, String accessKey,
            String secretKey) {

        public boolean configured() {
            return bucket != null && !bucket.isBlank();
        }
    }

    public record Ai(
            String apiKey,
            @DefaultValue("gemini-2.5-flash") String model,
            @DefaultValue("https://generativelanguage.googleapis.com/v1beta") String endpoint,
            @DefaultValue("5000ms") Duration timeout,
            @DefaultValue("0.5") double lowConfidenceThreshold) {

        public boolean configured() {
            return apiKey != null && !apiKey.isBlank();
        }
    }

    public record Demo(@DefaultValue("true") boolean enabled) {
    }
}
