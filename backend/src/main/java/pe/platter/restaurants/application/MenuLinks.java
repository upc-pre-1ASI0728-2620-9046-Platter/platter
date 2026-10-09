package pe.platter.restaurants.application;

import org.springframework.stereotype.Component;

import pe.platter.shared.config.PlatterProperties;

@Component
public class MenuLinks {

    private final String baseUrl;

    MenuLinks(PlatterProperties properties) {
        this.baseUrl = properties.publicWebUrl().replaceAll("/+$", "");
    }

    public String menuUrl(String tableToken) {
        return baseUrl + "/m/" + tableToken;
    }
}
