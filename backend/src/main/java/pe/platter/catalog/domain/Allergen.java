package pe.platter.catalog.domain;

import java.util.Arrays;
import java.util.Locale;
import java.util.Optional;

/** Alérgenos de declaración obligatoria (14 grupos normados). */
public enum Allergen {

    GLUTEN("Gluten", "🌾"),
    CRUSTACEANS("Crustáceos y mariscos", "🦐"),
    MOLLUSCS("Moluscos", "🦑"),
    FISH("Pescado", "🐟"),
    EGGS("Huevo", "🥚"),
    MILK("Lácteos", "🥛"),
    PEANUTS("Maní", "🥜"),
    TREE_NUTS("Frutos secos", "🌰"),
    SOY("Soya", "🫘"),
    SESAME("Ajonjolí", "⚪"),
    CELERY("Apio", "🥬"),
    MUSTARD("Mostaza", "🟡"),
    SULPHITES("Sulfitos", "🍷"),
    LUPIN("Altramuz (tarwi)", "🌼");

    private final String label;
    private final String icon;

    Allergen(String label, String icon) {
        this.label = label;
        this.icon = icon;
    }

    public static Optional<Allergen> parse(String code) {
        if (code == null) {
            return Optional.empty();
        }
        String normalized = code.trim().toUpperCase(Locale.ROOT);
        return Arrays.stream(values()).filter(a -> a.name().equals(normalized)).findFirst();
    }

    public String label() {
        return label;
    }

    public String icon() {
        return icon;
    }
}
