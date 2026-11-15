package pe.platter.demo;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

import pe.platter.catalog.domain.Allergen;
import pe.platter.catalog.domain.DishDetails;

/** Carta del restaurante demo "Sabores de Barranco": cocina peruana con algunos clásicos de la casa. */
final class DemoMenu {

    private DemoMenu() {
    }

    private static final String KITCHEN_NOTE =
            "Preparado en una cocina que manipula mariscos, gluten, lácteos y frutos secos.";

    /**
     * Plato de la carta demo. {@code photo}: imagen en {@code classpath:demo/photos/}; {@code popularity}: peso
     * relativo en las métricas generadas; {@code published}/{@code available}: estado inicial.
     */
    record Item(DishDetails details, String photo, int popularity, boolean published, boolean available) {
    }

    static final List<Item> ITEMS = List.of(
            item("Cebiche clásico", "Ceviches", "38.00",
                    "Pesca del día marinada al momento en limón de Chulucanas, ají limo y culantro, con cebolla morada "
                            + "crujiente, choclo desgranado y camote glaseado. Fresco, cítrico y con el punto justo de "
                            + "picor que define al cebiche limeño.",
                    List.of("Pescado blanco", "Limón", "Ají limo", "Cebolla morada", "Choclo", "Camote", "Culantro"),
                    EnumSet.of(Allergen.FISH), 320, 420, false, "ceviche", "ceviche-a", 10),
            item("Tiradito al ají amarillo", "Ceviches", "36.00",
                    "Láminas finas de pesca del día bañadas en una crema sedosa de ají amarillo y limón, con choclo "
                            + "tierno y canchita. La elegancia nikkei en un plato frío.",
                    List.of("Pescado blanco", "Ají amarillo", "Limón", "Choclo", "Canchita"),
                    EnumSet.of(Allergen.FISH), 280, 360, false, "ceviche", "ceviche-b", 6),
            item("Leche de tigre", "Entradas", "22.00",
                    "El jugo concentrado del cebiche, servido bien frío con trocitos de pescado, chicharrón de "
                            + "calamar y canchita. El levantamuertos más famoso de Lima.",
                    List.of("Pescado", "Limón", "Calamar", "Ají limo", "Canchita"),
                    EnumSet.of(Allergen.FISH, Allergen.MOLLUSCS, Allergen.GLUTEN), 210, 290, false, "bebida",
                    "bebida-c", 4),
            item("Causa limeña", "Entradas", "26.00",
                    "Suave masa de papa amarilla prensada con ají amarillo y limón, rellena de palta y pollo, coronada "
                            + "con mayonesa de la casa y huevo de codorniz. Fría, cremosa y llena de color.",
                    List.of("Papa amarilla", "Ají amarillo", "Limón", "Palta", "Pollo", "Mayonesa"),
                    EnumSet.of(Allergen.EGGS), 380, 460, false, "causa", "causa-a", 7),
            item("Papa a la huancaína", "Entradas", "19.00",
                    "Papas sancochadas bañadas en la clásica crema de ají amarillo, queso fresco y galleta, con huevo "
                            + "duro y aceituna de botija.",
                    List.of("Papa", "Ají amarillo", "Queso fresco", "Leche", "Galleta", "Huevo", "Aceituna"),
                    EnumSet.of(Allergen.MILK, Allergen.GLUTEN, Allergen.EGGS), 420, 520, true, "causa", "causa-b", 3),
            item("Lomo saltado", "Fondos", "45.00",
                    "Tiras de lomo fino salteadas al wok con cebolla, tomate y ají amarillo, flambeadas con sillao y "
                            + "vinagre. Con papas amarillas fritas y arroz graneado: el encuentro perfecto entre la "
                            + "cocina criolla y la chifa.",
                    List.of("Lomo de res", "Cebolla", "Tomate", "Ají amarillo", "Sillao", "Papas fritas", "Arroz"),
                    EnumSet.of(Allergen.SOY, Allergen.GLUTEN), 750, 900, false, "lomo-saltado", "lomo-saltado-a", 12),
            item("Tacu tacu con lomo", "Fondos", "42.00",
                    "Crujiente tacu tacu de frejoles canarios y arroz, dorado a la plancha, con lomo saltado jugoso y "
                            + "salsa criolla.",
                    List.of("Frejol canario", "Arroz", "Lomo de res", "Cebolla", "Tomate", "Sillao"),
                    EnumSet.of(Allergen.SOY, Allergen.GLUTEN), 820, 980, false, "lomo-saltado", "lomo-saltado-b", 5),
            item("Ají de gallina", "Criollos", "34.00",
                    "Gallina deshilachada en una crema sedosa de ají amarillo, pan remojado y pecanas, terminada con "
                            + "queso parmesano. Con arroz blanco, papa amarilla, huevo duro y aceituna de botija.",
                    List.of("Gallina", "Ají amarillo", "Pan", "Leche evaporada", "Pecanas", "Queso parmesano", "Huevo"),
                    EnumSet.of(Allergen.GLUTEN, Allergen.MILK, Allergen.TREE_NUTS, Allergen.EGGS), 680, 820, false,
                    "aji-de-gallina", "aji-de-gallina-a", 8),
            item("Seco de res con frejoles", "Criollos", "39.00",
                    "Asado de res cocido a fuego lento en culantro y chicha de jora hasta deshacerse, con frejoles "
                            + "canarios, arroz y salsa criolla.",
                    List.of("Res", "Culantro", "Chicha de jora", "Frejol canario", "Arroz", "Cebolla"),
                    EnumSet.noneOf(Allergen.class), 760, 900, false, "aji-de-gallina", "aji-de-gallina-b", 4),
            item("Hamburguesa de la casa", "Hamburguesas", "32.00",
                    "Carne de res de 180 g a la parrilla en pan brioche, con queso cheddar fundido, lechuga, tomate y "
                            + "salsa de ají. Acompañada de papas fritas crocantes.",
                    List.of("Carne de res", "Pan brioche", "Queso cheddar", "Lechuga", "Tomate", "Papas fritas"),
                    EnumSet.of(Allergen.GLUTEN, Allergen.MILK, Allergen.EGGS, Allergen.SESAME), 850, 1050, false,
                    "hamburguesa", "hamburguesa-a", 7),
            item("Sánguche de chicharrón", "Sánguches", "24.00",
                    "Pan francés crujiente con chicharrón de cerdo, camote frito y salsa criolla. El desayuno limeño "
                            + "de los domingos, a cualquier hora.",
                    List.of("Pan francés", "Chicharrón de cerdo", "Camote", "Cebolla", "Ají limo"),
                    EnumSet.of(Allergen.GLUTEN), 640, 780, false, "hamburguesa", "hamburguesa-b", 5),
            item("Pizza criolla", "Pizzas", "44.00",
                    "Masa madre horneada en piedra con salsa de tomate, mozzarella, lomo saltado, cebolla roja y un "
                            + "toque de ají amarillo. Para compartir entre dos.",
                    List.of("Harina", "Tomate", "Mozzarella", "Lomo de res", "Cebolla", "Ají amarillo"),
                    EnumSet.of(Allergen.GLUTEN, Allergen.MILK, Allergen.SOY), 1100, 1400, false, "pizza", "pizza-a", 3),
            item("Ensalada andina", "Ensaladas", "24.00",
                    "Quinua blanca, hojas verdes, tomates cherry, palta y queso fresco con vinagreta de maracuyá. "
                            + "Ligera, nutritiva y llena de sabores de nuestros Andes.",
                    List.of("Quinua", "Lechugas", "Tomate cherry", "Palta", "Queso fresco", "Maracuyá"),
                    EnumSet.of(Allergen.MILK), 300, 380, true, "ensalada", "ensalada-a", 4),
            item("Suspiro a la limeña", "Postres", "16.00",
                    "Manjar blanco de cocción lenta coronado con merengue al oporto y un toque de canela. El dulce más "
                            + "clásico de Lima.",
                    List.of("Leche", "Yemas", "Azúcar", "Oporto", "Canela"),
                    EnumSet.of(Allergen.MILK, Allergen.EGGS, Allergen.SULPHITES), 420, 520, true, "postre",
                    "postre-a", 5),
            item("Picarones con miel de chancaca", "Postres", "15.00",
                    "Anillos de masa de zapallo y camote fritos al momento, bañados en miel de chancaca con canela, "
                            + "clavo e higo.",
                    List.of("Zapallo", "Camote", "Harina", "Chancaca", "Canela", "Clavo"),
                    EnumSet.of(Allergen.GLUTEN), 380, 480, true, "postre", "postre-b", 4),
            item("Chicha morada", "Bebidas", "9.00",
                    "Refresco tradicional de maíz morado hervido con piña, canela y clavo, endulzado y con un toque de "
                            + "limón. Servida bien fría.",
                    List.of("Maíz morado", "Piña", "Canela", "Clavo de olor", "Limón"),
                    EnumSet.noneOf(Allergen.class), 120, 160, true, "bebida", "bebida-a", 4),
            item("Limonada frozen de hierbabuena", "Bebidas", "11.00",
                    "Limón recién exprimido licuado con hielo, hierbabuena y un toque de jarabe de caña.",
                    List.of("Limón", "Hierbabuena", "Hielo", "Jarabe de caña"),
                    EnumSet.noneOf(Allergen.class), 110, 150, true, "bebida", "bebida-b", 3));

    /** Borrador y agotado para que la demo muestre todos los estados del panel. */
    static final Item DRAFT = new Item(details("Arroz con mariscos", "Fondos", "48.00",
            "Arroz meloso con ají panca, mariscos frescos y un toque de pisco, terminado con salsa criolla.",
            List.of("Arroz", "Langostinos", "Calamar", "Conchas", "Ají panca", "Pisco"),
            EnumSet.of(Allergen.CRUSTACEANS, Allergen.MOLLUSCS, Allergen.SULPHITES), 700, 850, false,
            "lomo-saltado"), null, 0, false, true);

    static final String SOLD_OUT = "Tiradito al ají amarillo";

    private static Item item(String name, String category, String price, String description, List<String> ingredients,
            Set<Allergen> allergens, int calMin, int calMax, boolean vegetarian, String modelId, String photo,
            int popularity) {
        return new Item(details(name, category, price, description, ingredients, allergens, calMin, calMax,
                vegetarian, modelId), photo, popularity, true, !SOLD_OUT.equals(name));
    }

    private static DishDetails details(String name, String category, String price, String description,
            List<String> ingredients, Set<Allergen> allergens, int calMin, int calMax, boolean vegetarian,
            String modelId) {
        return new DishDetails(name, description, category, new BigDecimal(price), ingredients, allergens,
                allergens.isEmpty(), KITCHEN_NOTE, calMin, calMax, vegetarian, false, null, modelId);
    }

    /** Mesas del salón demo. La primera usa el token fijo "demo" (enlace público de la landing). */
    static final List<String> TABLES = List.of("Mesa 1", "Mesa 2", "Mesa 3", "Mesa 4", "Mesa 5", "Mesa 6", "Mesa 7",
            "Mesa 8", "Mesa 9", "Mesa 10", "Terraza 1", "Terraza 2", "Terraza 3", "Barra");

    static final String INACTIVE_TABLE = "Terraza 3";
}
