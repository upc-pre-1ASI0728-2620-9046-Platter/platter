package pe.platter.restaurants.domain;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Mesa física del salón. Su {@code token} es el TableSecureToken impreso en el QR: aleatorio y no secuencial. */
@Entity
@Table(name = "dining_tables")
public class DiningTable {

    private static final SecureRandom RANDOM = new SecureRandom();

    @Id
    private UUID id;

    @Column(name = "restaurant_id", nullable = false)
    private UUID restaurantId;

    @Column(nullable = false)
    private String label;

    @Column(nullable = false, unique = true)
    private String token;

    @Column(nullable = false)
    private boolean active;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected DiningTable() {
    }

    public DiningTable(UUID restaurantId, String label) {
        this(restaurantId, label, newToken());
    }

    public DiningTable(UUID restaurantId, String label, String token) {
        this.id = UUID.randomUUID();
        this.restaurantId = restaurantId;
        this.label = label;
        this.token = token;
        this.active = true;
        this.createdAt = Instant.now();
    }

    static String newToken() {
        byte[] bytes = new byte[16];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public UUID getId() {
        return id;
    }

    public UUID getRestaurantId() {
        return restaurantId;
    }

    public String getLabel() {
        return label;
    }

    public String getToken() {
        return token;
    }

    public boolean isActive() {
        return active;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
