package pe.platter.restaurants.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import pe.platter.billing.domain.Plan;

@Entity
@Table(name = "restaurants")
public class Restaurant {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String name;

    private String address;

    @Enumerated(EnumType.STRING)
    @Column(name = "plan_code", nullable = false)
    private Plan plan;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected Restaurant() {
    }

    public Restaurant(String name, String address, Plan plan) {
        this.id = UUID.randomUUID();
        this.name = name;
        this.address = address;
        this.plan = plan;
        this.createdAt = Instant.now();
    }

    public void updateProfile(String name, String address) {
        this.name = name;
        this.address = address;
    }

    public void changePlan(Plan plan) {
        this.plan = plan;
    }

    public UUID getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getAddress() {
        return address;
    }

    public Plan getPlan() {
        return plan;
    }
}
