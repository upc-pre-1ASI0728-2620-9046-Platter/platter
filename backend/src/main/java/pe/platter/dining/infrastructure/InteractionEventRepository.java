package pe.platter.dining.infrastructure;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import pe.platter.dining.domain.InteractionEvent;
import pe.platter.dining.domain.InteractionType;

public interface InteractionEventRepository extends JpaRepository<InteractionEvent, Long> {

    @Query("""
            select e.type as type, count(e) as total, avg(e.durationSeconds) as avgDuration
            from InteractionEvent e
            where e.restaurantId = :restaurantId and e.occurredAt >= :since
            group by e.type""")
    List<TypeTotal> totalsByType(UUID restaurantId, Instant since);

    @Query("""
            select e.dishId as dishId,
                   sum(case when e.type = :view then 1 else 0 end) as views,
                   sum(case when e.type = :ar then 1 else 0 end) as arLaunches
            from InteractionEvent e
            where e.restaurantId = :restaurantId and e.occurredAt >= :since and e.dishId is not null
            group by e.dishId""")
    List<DishTotal> totalsByDish(UUID restaurantId, Instant since, InteractionType view, InteractionType ar);

    @Query("""
            select e.tableId as tableId, count(e) as scans
            from InteractionEvent e
            where e.restaurantId = :restaurantId and e.occurredAt >= :since and e.type = :type
              and e.tableId is not null
            group by e.tableId
            order by count(e) desc""")
    List<TableTotal> scansByTable(UUID restaurantId, Instant since, InteractionType type);

    interface TypeTotal {
        InteractionType getType();

        long getTotal();

        Double getAvgDuration();
    }

    interface DishTotal {
        UUID getDishId();

        long getViews();

        long getArLaunches();
    }

    interface TableTotal {
        UUID getTableId();

        long getScans();
    }
}
