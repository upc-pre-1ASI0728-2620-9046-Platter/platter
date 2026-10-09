package pe.platter;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.UUID;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.AbstractMockHttpServletRequestBuilder;

import com.jayway.jsonpath.JsonPath;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PlatterApiIntegrationTest {

    @Autowired
    MockMvc mvc;

    String token;

    @BeforeEach
    void registerOwner() throws Exception {
        String email = "owner-" + UUID.randomUUID() + "@test.pe";
        MvcResult result = mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"ownerName":"Rosa","email":"%s","password":"secreto123",
                                 "restaurantName":"La Picantería","address":"Arequipa"}""".formatted(email)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.restaurant.plan.code").value("EMPRENDEDOR"))
                .andExpect(jsonPath("$.expiresIn").value(3600))
                .andReturn();
        token = JsonPath.read(result.getResponse().getContentAsString(), "$.token");
    }

    private <B extends AbstractMockHttpServletRequestBuilder<B>> B auth(B builder) {
        return builder.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
    }

    @Test
    void loginAndProtectedEndpoints() throws Exception {
        mvc.perform(get("/api/v1/dishes")).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"demo@platter.pe\",\"password\":\"incorrecta\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"DEMO@platter.pe\",\"password\":\"demo12345\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.restaurant.name").value("Sabores de Barranco (Demo)"));
        mvc.perform(auth(get("/api/v1/me"))).andExpect(status().isOk())
                .andExpect(jsonPath("$.user.name").value("Rosa"));
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ownerName\":\"X\",\"email\":\"no-es-correo\",\"password\":\"123\","
                                + "\"restaurantName\":\"Y\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.email").exists())
                .andExpect(jsonPath("$.details.password").exists());
    }

    @Test
    void tablesQrAndPlanLimits() throws Exception {
        mvc.perform(auth(post("/api/v1/tables/batch")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"from\":1,\"to\":10}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$", hasSize(10)))
                .andExpect(jsonPath("$[0].label").value("Mesa 1"))
                .andExpect(jsonPath("$[0].menuUrl", startsWith("https://platter.test/m/")));
        // Lote solapado: solo se crean las mesas nuevas, sin alterar las existentes.
        mvc.perform(auth(post("/api/v1/tables/batch")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"from\":9,\"to\":12}"))
                .andExpect(jsonPath("$", hasSize(2)));
        MvcResult terrace = mvc.perform(auth(post("/api/v1/tables")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"Terraza 01\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        String tableId = JsonPath.read(terrace.getResponse().getContentAsString(), "$.id");
        String tableToken = JsonPath.read(terrace.getResponse().getContentAsString(), "$.token");
        assertThat(tableToken).hasSize(22);
        mvc.perform(auth(post("/api/v1/tables")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"terraza 01\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("DUPLICATE_TABLE"));
        // Plan Emprendedor: máximo 15 mesas (13 creadas).
        mvc.perform(auth(post("/api/v1/tables/batch")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"from\":20,\"to\":25}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("PLAN_LIMIT_REACHED"));

        mvc.perform(auth(get("/api/v1/tables/" + tableId + "/qr.png")).param("size", "256"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_TYPE, "image/png"));
        MvcResult pdf = mvc.perform(get("/api/v1/tables/qr-sheet.pdf").param("access_token", token))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_TYPE, "application/pdf"))
                .andReturn();
        assertThat(new String(pdf.getResponse().getContentAsByteArray(), 0, 5)).isEqualTo("%PDF-");

        mvc.perform(get("/api/v1/public/tables/" + tableToken)).andExpect(status().isOk())
                .andExpect(jsonPath("$.table.label").value("Terraza 01"))
                .andExpect(jsonPath("$.restaurant.name").value("La Picantería"));
        mvc.perform(auth(patch("/api/v1/tables/" + tableId)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"active\":false}"))
                .andExpect(jsonPath("$.active").value(false));
        mvc.perform(get("/api/v1/public/tables/" + tableToken)).andExpect(jsonPath("$.table.active").value(false));
        mvc.perform(get("/api/v1/public/tables/no-existe")).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("TABLE_NOT_FOUND"));

        mvc.perform(auth(put("/api/v1/restaurant/plan")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"planCode\":\"PRO\"}"))
                .andExpect(jsonPath("$.plan.maxTables").doesNotExist())
                .andExpect(jsonPath("$.tableCount").value(13));
    }

    @Test
    void dishLifecycleFromPhotoToPublicMenu() throws Exception {
        MvcResult upload = mvc.perform(auth(multipart("/api/v1/dishes/photos").file(png("image"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.photoUrl", containsString("/api/v1/media/photos/")))
                .andReturn();
        String photoId = JsonPath.read(upload.getResponse().getContentAsString(), "$.photoId");
        mvc.perform(get("/api/v1/media/photos/" + photoId)).andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_TYPE, "image/png"));
        mvc.perform(auth(multipart("/api/v1/dishes/photos")
                        .file(new MockMultipartFile("image", "x.gif", "image/gif", "GIF89a....".getBytes()))))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.code").value("UNSUPPORTED_IMAGE"));

        // QA-03: sin proveedor de IA disponible se responde 503 controlado y se habilita la carga manual.
        mvc.perform(auth(multipart("/api/v1/dishes/analyze").param("photoId", photoId)))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("AI_UNAVAILABLE"))
                .andExpect(jsonPath("$.details.manualEntryAllowed").value(true));

        MvcResult created = mvc.perform(auth(post("/api/v1/dishes")).contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Cebiche de corvina","category":"Ceviches","ingredients":["Corvina","Limón"],
                                 "allergens":["FISH"],"photoId":"%s"}""".formatted(photoId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andReturn();
        String dishId = JsonPath.read(created.getResponse().getContentAsString(), "$.id");

        mvc.perform(auth(post("/api/v1/dishes/" + dishId + "/publish")))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.code").value("DISH_NOT_PUBLISHABLE"))
                .andExpect(jsonPath("$.details.priceSoles").exists());

        mvc.perform(auth(put("/api/v1/dishes/" + dishId)).contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Cebiche de corvina","category":"Ceviches","priceSoles":42.5,
                                 "ingredients":["Corvina","Limón"],"allergens":["FISH"],
                                 "caloriesMin":300,"caloriesMax":400}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.photoId").value(photoId));
        mvc.perform(auth(post("/api/v1/dishes/" + dishId + "/publish")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.model.id").exists());

        String restaurantId = JsonPath.read(mvc.perform(auth(get("/api/v1/restaurant"))).andReturn()
                .getResponse().getContentAsString(), "$.id");
        mvc.perform(get("/api/v1/public/restaurants/" + restaurantId + "/menu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.categories[0].name").value("Ceviches"))
                .andExpect(jsonPath("$.categories[0].dishes[0].priceSoles").value(42.5))
                .andExpect(jsonPath("$.categories[0].dishes[0].available").value(true));
        // US15: el filtro de alérgenos excluye el plato.
        mvc.perform(get("/api/v1/public/restaurants/" + restaurantId + "/menu").param("exclude", "fish,GLUTEN"))
                .andExpect(jsonPath("$.categories", hasSize(0)))
                .andExpect(jsonPath("$.excludedAllergens", hasItem("FISH")));
        // US18: "Agotado por hoy" se refleja de inmediato en la carta (caché invalidada).
        // Un plato publicado no puede quedar con la ficha incompleta.
        mvc.perform(auth(put("/api/v1/dishes/" + dishId)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Cebiche\",\"category\":\"Ceviches\",\"allergens\":[\"FISH\"]}"))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.details.priceSoles").exists());
        mvc.perform(auth(patch("/api/v1/dishes/" + dishId + "/availability")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"available\":false}"))
                .andExpect(jsonPath("$.available").value(false));
        mvc.perform(get("/api/v1/public/restaurants/" + restaurantId + "/menu"))
                .andExpect(jsonPath("$.categories[0].dishes[0].available").value(false));

        mvc.perform(auth(delete("/api/v1/dishes/" + dishId))).andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/public/restaurants/" + restaurantId + "/menu"))
                .andExpect(jsonPath("$.categories", hasSize(0)));
    }

    @Test
    void ownersCannotSeeOtherRestaurantsData() throws Exception {
        String demoToken = JsonPath.read(mvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"demo@platter.pe\",\"password\":\"demo12345\"}")).andReturn()
                .getResponse().getContentAsString(), "$.token");
        String demoDishId = JsonPath.read(mvc.perform(get("/api/v1/dishes")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + demoToken)).andReturn()
                .getResponse().getContentAsString(), "$[0].id");
        mvc.perform(auth(get("/api/v1/dishes/" + demoDishId))).andExpect(status().isNotFound());
        mvc.perform(auth(get("/api/v1/dishes"))).andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    void demoMenuEventsAndAnalytics() throws Exception {
        String restaurantId = JsonPath.read(mvc.perform(get("/api/v1/public/tables/demo")).andReturn()
                .getResponse().getContentAsString(), "$.restaurant.id");
        MvcResult menu = mvc.perform(get("/api/v1/public/restaurants/" + restaurantId + "/menu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.categories[*].name", hasItem("Ceviches")))
                .andReturn();
        String dishId = JsonPath.read(menu.getResponse().getContentAsString(), "$.categories[0].dishes[0].id");

        for (String body : new String[] {
                "{\"type\":\"QR_SCAN\",\"tableToken\":\"demo\"}",
                "{\"type\":\"DISH_VIEW\",\"tableToken\":\"demo\",\"dishId\":\"" + dishId + "\"}",
                "{\"type\":\"AR_LAUNCH\",\"tableToken\":\"demo\",\"dishId\":\"" + dishId + "\"}",
                "{\"type\":\"AR_SESSION_END\",\"dishId\":\"" + dishId + "\",\"durationSeconds\":20}"}) {
            mvc.perform(post("/api/v1/public/events").contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isAccepted());
        }
        mvc.perform(post("/api/v1/public/events").contentType(MediaType.APPLICATION_JSON)
                .content("{\"type\":\"HACK\"}")).andExpect(status().isBadRequest());

        String demoToken = JsonPath.read(mvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"demo@platter.pe\",\"password\":\"demo12345\"}")).andReturn()
                .getResponse().getContentAsString(), "$.token");
        mvc.perform(get("/api/v1/analytics/summary").header(HttpHeaders.AUTHORIZATION, "Bearer " + demoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.qrScans").value(org.hamcrest.Matchers.greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.arLaunches").value(org.hamcrest.Matchers.greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.topDishes[0].dishId").value(dishId))
                .andExpect(jsonPath("$.topTables[0].label").value("Mesa Demo"));
    }

    @Test
    void referenceDataLeadsAndModels() throws Exception {
        mvc.perform(get("/api/v1/plans")).andExpect(jsonPath("$", hasSize(3)))
                .andExpect(jsonPath("$[0].priceSoles").value(49.0));
        mvc.perform(get("/api/v1/allergens")).andExpect(jsonPath("$", hasSize(14)));
        mvc.perform(get("/api/v1/categories")).andExpect(jsonPath("$", hasItem("Ceviches")));
        mvc.perform(post("/api/v1/public/leads").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"restaurantName":"El Criollo","contactName":"Ana","email":"ana@criollo.pe",
                                 "phone":"+51 987654321","tables":12}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message", containsString("24 horas")));
        mvc.perform(post("/api/v1/public/leads").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"restaurantName\":\"\",\"email\":\"x\",\"tables\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.details.email").value("Correo inválido"));

        MvcResult models = mvc.perform(get("/api/v1/models")).andExpect(status().isOk())
                .andExpect(jsonPath("$", not(hasSize(0))))
                .andReturn();
        String glbUrl = JsonPath.read(models.getResponse().getContentAsString(), "$[0].glbUrl");
        String path = glbUrl.substring(glbUrl.indexOf("/api/"));
        MvcResult glb = mvc.perform(get(path)).andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_TYPE, "model/gltf-binary"))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("immutable")))
                .andReturn();
        assertThat(new String(glb.getResponse().getContentAsByteArray(), 0, 4)).isEqualTo("glTF");
        String etag = glb.getResponse().getHeader(HttpHeaders.ETAG);
        mvc.perform(get(path).header(HttpHeaders.IF_NONE_MATCH, etag)).andExpect(status().isNotModified());
        mvc.perform(get("/api/v1/assets/models/no-existe.glb")).andExpect(status().isNotFound());
    }

    private static MockMultipartFile png(String part) throws Exception {
        BufferedImage image = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, "png", out);
        return new MockMultipartFile(part, "plato.png", "image/png", out.toByteArray());
    }
}
