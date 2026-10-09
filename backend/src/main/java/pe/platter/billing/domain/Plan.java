package pe.platter.billing.domain;

import java.math.BigDecimal;

/** Planes de suscripción MYPE (CON-06: entre S/ 49 y S/ 129 al mes). {@code null} = ilimitado. */
public enum Plan {

    EMPRENDEDOR("Emprendedor", new BigDecimal("49.00"), 15, 30, true),
    CRECIMIENTO("Crecimiento", new BigDecimal("89.00"), 40, 120, true),
    PRO("Pro", new BigDecimal("129.00"), null, null, true);

    private final String displayName;
    private final BigDecimal priceSoles;
    private final Integer maxTables;
    private final Integer maxDishes;
    private final boolean aiAnalysis;

    Plan(String displayName, BigDecimal priceSoles, Integer maxTables, Integer maxDishes, boolean aiAnalysis) {
        this.displayName = displayName;
        this.priceSoles = priceSoles;
        this.maxTables = maxTables;
        this.maxDishes = maxDishes;
        this.aiAnalysis = aiAnalysis;
    }

    public boolean allowsTables(long count) {
        return maxTables == null || count <= maxTables;
    }

    public boolean allowsDishes(long count) {
        return maxDishes == null || count <= maxDishes;
    }

    public String displayName() {
        return displayName;
    }

    public BigDecimal priceSoles() {
        return priceSoles;
    }

    public Integer maxTables() {
        return maxTables;
    }

    public Integer maxDishes() {
        return maxDishes;
    }

    public boolean aiAnalysis() {
        return aiAnalysis;
    }
}
