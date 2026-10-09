package pe.platter.catalog.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Fotografía de referencia de un plato. El binario vive en el almacenamiento de objetos. */
@Entity
@Table(name = "photos")
public class Photo {

    @Id
    private UUID id;

    @Column(name = "restaurant_id", nullable = false)
    private UUID restaurantId;

    @Column(name = "storage_key", nullable = false)
    private String storageKey;

    @Column(name = "content_type", nullable = false)
    private String contentType;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected Photo() {
    }

    public Photo(UUID restaurantId, String contentType, long sizeBytes) {
        this.id = UUID.randomUUID();
        this.restaurantId = restaurantId;
        this.contentType = contentType;
        this.sizeBytes = sizeBytes;
        this.storageKey = "photos/" + restaurantId + "/" + id + (contentType.endsWith("png") ? ".png" : ".jpg");
        this.createdAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getRestaurantId() {
        return restaurantId;
    }

    public String getStorageKey() {
        return storageKey;
    }

    public String getContentType() {
        return contentType;
    }
}
