package pe.platter.shared.security;

import java.util.UUID;

/** Dueño autenticado, resuelto a partir del JWT. Aísla los datos por restaurante (multi-tenancy lógico). */
public record CurrentOwner(UUID userId, UUID restaurantId) {
}
