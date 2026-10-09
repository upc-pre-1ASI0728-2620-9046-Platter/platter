package pe.platter.leads.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Solicitud de piloto gratuito de 14 días enviada desde la landing (US04). */
@Entity
@Table(name = "leads")
public class Lead {

    @Id
    private UUID id;

    @Column(name = "restaurant_name", nullable = false)
    private String restaurantName;

    @Column(name = "contact_name", nullable = false)
    private String contactName;

    @Column(nullable = false)
    private String email;

    @Column(nullable = false)
    private String phone;

    @Column(nullable = false)
    private int tables;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected Lead() {
    }

    public Lead(String restaurantName, String contactName, String email, String phone, int tables) {
        this.id = UUID.randomUUID();
        this.restaurantName = restaurantName;
        this.contactName = contactName;
        this.email = email;
        this.phone = phone;
        this.tables = tables;
        this.createdAt = Instant.now();
    }
}
