package pe.platter.demo;

import java.sql.Timestamp;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import pe.platter.dining.domain.InteractionType;

/**
 * Métricas de ejemplo para el restaurante demo: ~5 semanas de escaneos, vistas y sesiones AR con horarios de
 * almuerzo y cena, más movimiento los fines de semana y una ligera tendencia al alza. Se regeneran al arrancar
 * cuando el último evento tiene más de unas horas, para que los resúmenes de 7 y 30 días siempre tengan datos.
 */
@Component
class DemoHistoryGenerator {

    private static final Logger log = LoggerFactory.getLogger(DemoHistoryGenerator.class);
    private static final ZoneId LIMA = ZoneId.of("America/Lima");
    private static final int DAYS = 35;
    private static final Duration STALE_AFTER = Duration.ofHours(6);
    private static final int MIN_WEEKLY_EVENTS = 200;
    private static final String INSERT = "insert into interaction_events "
            + "(restaurant_id, table_id, dish_id, type, duration_seconds, occurred_at) values (?, ?, ?, ?, ?, ?)";

    private final JdbcTemplate jdbc;

    DemoHistoryGenerator(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    void refreshIfStale(UUID restaurantId) {
        Timestamp last = jdbc.queryForObject(
                "select max(occurred_at) from interaction_events where restaurant_id = ?", Timestamp.class,
                restaurantId);
        Integer lastWeek = jdbc.queryForObject(
                "select count(*) from interaction_events where restaurant_id = ? and occurred_at >= ?", Integer.class,
                restaurantId, Timestamp.from(Instant.now().minus(Duration.ofDays(7))));
        // Unos pocos escaneos reales recientes no cuentan como historial: se regenera si la semana está casi vacía.
        boolean recent = last != null && last.toInstant().isAfter(Instant.now().minus(STALE_AFTER));
        if (recent && lastWeek != null && lastWeek >= MIN_WEEKLY_EVENTS) {
            return;
        }
        Map<String, UUID> dishIds = new HashMap<>();
        jdbc.query("select id, name from dishes where restaurant_id = ? and status = 'PUBLISHED'",
                rs -> {
                    dishIds.put(rs.getString("name"), rs.getObject("id", UUID.class));
                }, restaurantId);
        List<UUID> tableIds = new ArrayList<>();
        List<Integer> tableWeights = new ArrayList<>();
        jdbc.query("select id, label from dining_tables where restaurant_id = ? and active = true order by label",
                rs -> {
                    String label = rs.getString("label");
                    tableIds.add(rs.getObject("id", UUID.class));
                    // Las mesas junto a la ventana y la terraza se usan más.
                    tableWeights.add(label.startsWith("Terraza") ? 5 : label.equals("Barra") ? 2
                            : label.equals("Mesa 4") || label.equals("Mesa 7") ? 6 : 3);
                }, restaurantId);
        if (dishIds.isEmpty() || tableIds.isEmpty()) {
            return;
        }
        List<UUID> dishes = new ArrayList<>();
        List<Integer> dishWeights = new ArrayList<>();
        for (DemoMenu.Item item : DemoMenu.ITEMS) {
            UUID id = dishIds.get(item.details().name());
            if (id != null && item.popularity() > 0) {
                dishes.add(id);
                dishWeights.add(item.popularity());
            }
        }

        List<Object[]> rows = generate(restaurantId, dishes, dishWeights, tableIds, tableWeights);
        jdbc.update("delete from interaction_events where restaurant_id = ?", restaurantId);
        jdbc.batchUpdate(INSERT, rows, 500, (ps, row) -> {
            for (int i = 0; i < row.length; i++) {
                ps.setObject(i + 1, row[i]);
            }
        });
        log.info("Métricas demo regeneradas: {} eventos en {} días", rows.size(), DAYS);
    }

    private static List<Object[]> generate(UUID restaurantId, List<UUID> dishes, List<Integer> dishWeights,
            List<UUID> tables, List<Integer> tableWeights) {
        Random random = new Random(20261115L);
        Instant now = Instant.now();
        LocalDate today = LocalDate.now(LIMA);
        List<Object[]> rows = new ArrayList<>();
        for (int daysAgo = DAYS - 1; daysAgo >= 0; daysAgo--) {
            LocalDate day = today.minusDays(daysAgo);
            DayOfWeek dow = day.getDayOfWeek();
            double base = switch (dow) {
                case FRIDAY, SATURDAY -> 58;
                case SUNDAY -> 50;
                case MONDAY -> 22;
                default -> 32;
            };
            double trend = 0.72 + 0.28 * (DAYS - 1 - daysAgo) / (DAYS - 1.0);
            int scans = (int) Math.round(base * trend * (0.8 + random.nextDouble() * 0.4));
            for (int s = 0; s < scans; s++) {
                ZonedDateTime at = day.atTime(serviceHour(random), random.nextInt(60)).atZone(LIMA);
                Instant scanAt = at.toInstant();
                if (scanAt.isAfter(now)) {
                    continue;
                }
                UUID table = pick(tables, tableWeights, random);
                rows.add(row(restaurantId, table, null, InteractionType.QR_SCAN, null, scanAt));
                int views = 1 + (random.nextDouble() < 0.7 ? 1 : 0) + (random.nextDouble() < 0.45 ? 1 : 0)
                        + (random.nextDouble() < 0.2 ? 1 : 0);
                Instant t = scanAt;
                for (int v = 0; v < views; v++) {
                    t = t.plusSeconds(20 + random.nextInt(140));
                    if (t.isAfter(now)) {
                        break;
                    }
                    UUID dish = pick(dishes, dishWeights, random);
                    rows.add(row(restaurantId, table, dish, InteractionType.DISH_VIEW, null, t));
                    if (random.nextDouble() < 0.46) {
                        Instant ar = t.plusSeconds(5 + random.nextInt(25));
                        int seconds = 14 + random.nextInt(48) + (random.nextDouble() < 0.25 ? random.nextInt(60) : 0);
                        rows.add(row(restaurantId, table, dish, InteractionType.AR_LAUNCH, null, ar));
                        Instant end = ar.plusSeconds(seconds);
                        if (!end.isAfter(now)) {
                            rows.add(row(restaurantId, null, dish, InteractionType.AR_SESSION_END, seconds, end));
                        }
                        t = end;
                    }
                }
            }
        }
        return rows;
    }

    /** Hora local: picos de almuerzo (12–15 h) y cena (19–22 h). */
    private static int serviceHour(Random random) {
        double r = random.nextDouble();
        if (r < 0.52) {
            return 12 + random.nextInt(4);
        }
        if (r < 0.9) {
            return 19 + random.nextInt(4);
        }
        return 16 + random.nextInt(3);
    }

    private static Object[] row(UUID restaurantId, UUID table, UUID dish, InteractionType type, Integer duration,
            Instant at) {
        return new Object[] {restaurantId, table, dish, type.name(), duration, Timestamp.from(at)};
    }

    private static <T> T pick(List<T> items, List<Integer> weights, Random random) {
        int total = weights.stream().mapToInt(Integer::intValue).sum();
        int r = random.nextInt(total);
        for (int i = 0; i < items.size(); i++) {
            r -= weights.get(i);
            if (r < 0) {
                return items.get(i);
            }
        }
        return items.getLast();
    }
}
