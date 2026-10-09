package pe.platter.assets.interfaces;

import pe.platter.assets.domain.DishModel;
import pe.platter.shared.web.ApiUrls;

public record ModelResource(String id, String name, String category, String glbUrl,
        DishModel.Dimensions dimensions) {

    public static ModelResource from(DishModel model) {
        return new ModelResource(model.id(), model.name(), model.category(),
                ApiUrls.of("/api/v1/assets/models/" + model.id() + ".glb"), model.dimensions());
    }
}
