package pe.platter.dining.application;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.catalog.application.DishService;
import pe.platter.catalog.domain.Dish;
import pe.platter.dining.domain.InteractionType;
import pe.platter.dining.infrastructure.InteractionEventRepository;
import pe.platter.dining.infrastructure.InteractionEventRepository.TypeTotal;
import pe.platter.restaurants.application.TableService;
import pe.platter.restaurants.domain.DiningTable;

/** US19: platos más explorados en AR y mesas con mayor interacción. */
@Service
public class AnalyticsService {

    private final InteractionEventRepository events;
    private final DishService dishes;
    private final TableService tables;

    AnalyticsService(InteractionEventRepository events, DishService dishes, TableService tables) {
        this.events = events;
        this.dishes = dishes;
        this.tables = tables;
    }

    @Transactional(readOnly = true)
    public Summary summary(UUID restaurantId, int days) {
        Instant since = Instant.now().minus(Duration.ofDays(days));
        Map<InteractionType, TypeTotal> totals = events.totalsByType(restaurantId, since).stream()
                .collect(Collectors.toMap(TypeTotal::getType, Function.identity()));
        Map<UUID, String> dishNames = dishes.list(restaurantId).stream()
                .collect(Collectors.toMap(Dish::getId, Dish::getName));
        Map<UUID, String> tableLabels = tables.list(restaurantId).stream()
                .collect(Collectors.toMap(DiningTable::getId, DiningTable::getLabel));

        List<TopDish> topDishes = events.totalsByDish(restaurantId, since, InteractionType.DISH_VIEW,
                        InteractionType.AR_LAUNCH).stream()
                .filter(d -> dishNames.containsKey(d.getDishId()))
                .map(d -> new TopDish(d.getDishId(), dishNames.get(d.getDishId()), d.getViews(), d.getArLaunches()))
                .sorted(Comparator.comparingLong(TopDish::arLaunches).thenComparingLong(TopDish::views).reversed())
                .limit(10)
                .toList();
        List<TopTable> topTables = events.scansByTable(restaurantId, since, InteractionType.QR_SCAN).stream()
                .filter(t -> tableLabels.containsKey(t.getTableId()))
                .limit(10)
                .map(t -> new TopTable(tableLabels.get(t.getTableId()), t.getScans()))
                .toList();
        TypeTotal arEnd = totals.get(InteractionType.AR_SESSION_END);
        double avgAr = arEnd == null || arEnd.getAvgDuration() == null ? 0
                : Math.round(arEnd.getAvgDuration() * 10) / 10.0;
        return new Summary(days, count(totals, InteractionType.QR_SCAN), count(totals, InteractionType.DISH_VIEW),
                count(totals, InteractionType.AR_LAUNCH), avgAr, topDishes, topTables);
    }

    private static long count(Map<InteractionType, TypeTotal> totals, InteractionType type) {
        TypeTotal total = totals.get(type);
        return total == null ? 0 : total.getTotal();
    }

    public record Summary(int days, long qrScans, long dishViews, long arLaunches, double avgArSeconds,
            List<TopDish> topDishes, List<TopTable> topTables) {
    }

    public record TopDish(UUID dishId, String name, long views, long arLaunches) {
    }

    public record TopTable(String label, long scans) {
    }
}
