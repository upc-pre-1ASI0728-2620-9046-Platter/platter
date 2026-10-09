package pe.platter.assets.domain;

/** DracoModelAsset de la biblioteca normalizada: modelo 3D calibrado a escala real (metros). */
public record DishModel(String id, String name, String category, Dimensions dimensions) {

    public record Dimensions(double widthM, double depthM, double heightM) {
    }
}
