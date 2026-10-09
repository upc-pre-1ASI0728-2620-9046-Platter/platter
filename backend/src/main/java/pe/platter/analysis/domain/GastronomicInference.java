package pe.platter.analysis.domain;

import java.util.List;

/** Metadata gastronómica inferida a partir de una fotografía (lenguaje ubicuo interno, independiente de Gemini). */
public record GastronomicInference(
        boolean food,
        double confidence,
        String suggestedName,
        String description,
        String category,
        List<String> ingredients,
        List<String> allergenCodes,
        Integer caloriesMin,
        Integer caloriesMax) {
}
