package pe.platter.restaurants.application;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.billing.application.PlanPolicy;
import pe.platter.restaurants.domain.DiningTable;
import pe.platter.restaurants.domain.Restaurant;
import pe.platter.restaurants.infrastructure.DiningTableRepository;
import pe.platter.shared.api.PlatterException;

@Service
public class TableService {

    private final DiningTableRepository tables;
    private final RestaurantService restaurants;
    private final PlanPolicy planPolicy;

    TableService(DiningTableRepository tables, RestaurantService restaurants, PlanPolicy planPolicy) {
        this.tables = tables;
        this.restaurants = restaurants;
        this.planPolicy = planPolicy;
    }

    @Transactional(readOnly = true)
    public List<DiningTable> list(UUID restaurantId) {
        return tables.findByRestaurantIdOrderByCreatedAtAscLabelAsc(restaurantId);
    }

    @Transactional(readOnly = true)
    public DiningTable get(UUID restaurantId, UUID tableId) {
        return tables.findByIdAndRestaurantId(tableId, restaurantId)
                .orElseThrow(() -> PlatterException.notFound("Mesa"));
    }

    /** US11 Scenario 1: generación masiva por rango. Las etiquetas que ya existen se omiten. */
    @Transactional
    public List<DiningTable> createRange(UUID restaurantId, int from, int to, String prefix) {
        if (from < 1 || to < from || to - from >= 200) {
            throw new PlatterException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Rango de mesas inválido",
                    java.util.Map.of("to", "Debe ser mayor o igual a 'from' (máximo 200 mesas por lote)"));
        }
        String base = prefix == null || prefix.isBlank() ? "Mesa" : prefix.trim();
        List<String> labels = new ArrayList<>();
        for (int n = from; n <= to; n++) {
            String label = base + " " + n;
            if (!tables.existsByRestaurantIdAndLabelIgnoreCase(restaurantId, label)) {
                labels.add(label);
            }
        }
        ensureCapacity(restaurantId, labels.size());
        return tables.saveAll(labels.stream().map(l -> new DiningTable(restaurantId, l)).toList());
    }

    /** US11 Scenario 2: una mesa adicional sin alterar los QR existentes. */
    @Transactional
    public DiningTable create(UUID restaurantId, String label) {
        String clean = label.trim();
        if (tables.existsByRestaurantIdAndLabelIgnoreCase(restaurantId, clean)) {
            throw new PlatterException(HttpStatus.CONFLICT, "DUPLICATE_TABLE", "Ya existe una mesa llamada " + clean);
        }
        ensureCapacity(restaurantId, 1);
        return tables.save(new DiningTable(restaurantId, clean));
    }

    @Transactional
    public DiningTable setActive(UUID restaurantId, UUID tableId, boolean active) {
        DiningTable table = get(restaurantId, tableId);
        table.setActive(active);
        return table;
    }

    private void ensureCapacity(UUID restaurantId, int adding) {
        Restaurant restaurant = restaurants.get(restaurantId);
        planPolicy.ensureTablesAllowed(restaurant.getPlan(), tables.countByRestaurantId(restaurantId) + adding);
    }
}
