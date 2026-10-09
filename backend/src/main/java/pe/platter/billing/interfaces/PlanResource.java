package pe.platter.billing.interfaces;

import java.math.BigDecimal;

import pe.platter.billing.domain.Plan;

public record PlanResource(String code, String name, BigDecimal priceSoles, Integer maxTables, Integer maxDishes,
        boolean aiAnalysis) {

    public static PlanResource from(Plan plan) {
        return new PlanResource(plan.name(), plan.displayName(), plan.priceSoles(), plan.maxTables(),
                plan.maxDishes(), plan.aiAnalysis());
    }
}
