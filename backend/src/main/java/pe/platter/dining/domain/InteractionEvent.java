package pe.platter.dining.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Métrica anónima de interacción del comensal (no guarda datos personales). */
@Entity
@Table(name = "interaction_events")
public class InteractionEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "restaurant_id", nullable = false)
    private UUID restaurantId;

    @Column(name = "table_id")
    private UUID tableId;

    @Column(name = "dish_id")
    private UUID dishId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private InteractionType type;

    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    protected InteractionEvent() {
    }

    public InteractionEvent(UUID restaurantId, UUID tableId, UUID dishId, InteractionType type,
            Integer durationSeconds) {
        this.restaurantId = restaurantId;
        this.tableId = tableId;
        this.dishId = dishId;
        this.type = type;
        this.durationSeconds = durationSeconds;
        this.occurredAt = Instant.now();
    }
}
