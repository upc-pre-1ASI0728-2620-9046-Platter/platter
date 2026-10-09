package pe.platter.billing.application;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import pe.platter.billing.domain.Plan;
import pe.platter.shared.api.PlatterException;

/** Contexto upstream que regula los límites operativos de Mesas y Catálogo (Context Map: Governance). */
@Service
public class PlanPolicy {

    public void ensureTablesAllowed(Plan plan, long resultingCount) {
        if (!plan.allowsTables(resultingCount)) {
            throw limit("mesas", plan, plan.maxTables());
        }
    }

    public void ensureDishesAllowed(Plan plan, long resultingCount) {
        if (!plan.allowsDishes(resultingCount)) {
            throw limit("platos", plan, plan.maxDishes());
        }
    }

    private static PlatterException limit(String resource, Plan plan, Integer max) {
        return new PlatterException(HttpStatus.FORBIDDEN, "PLAN_LIMIT_REACHED",
                "Tu plan " + plan.displayName() + " permite hasta " + max + " " + resource
                        + ". Mejora tu plan para agregar más.",
                Map.of("plan", plan.name(), "limit", max));
    }
}
