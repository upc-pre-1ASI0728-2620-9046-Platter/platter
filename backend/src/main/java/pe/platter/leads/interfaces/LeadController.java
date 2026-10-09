package pe.platter.leads.interfaces;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.leads.domain.Lead;
import pe.platter.leads.infrastructure.LeadRepository;

@RestController
class LeadController {

    private final LeadRepository leads;

    LeadController(LeadRepository leads) {
        this.leads = leads;
    }

    @PostMapping("/api/v1/public/leads")
    @ResponseStatus(HttpStatus.CREATED)
    LeadResponse create(@Valid @RequestBody LeadRequest request) {
        leads.save(new Lead(request.restaurantName().trim(), request.contactName().trim(),
                request.email().trim().toLowerCase(java.util.Locale.ROOT), request.phone().trim(), request.tables()));
        return new LeadResponse("¡Gracias! Recibirás tu acceso al piloto gratuito en menos de 24 horas.");
    }

    record LeadRequest(
            @NotBlank(message = "Ingresa el nombre de tu restaurante") @Size(max = 120) String restaurantName,
            @NotBlank(message = "Ingresa tu nombre") @Size(max = 120) String contactName,
            @NotBlank(message = "Ingresa tu correo") @Email(message = "Correo inválido") @Size(max = 180) String email,
            @NotBlank(message = "Ingresa tu teléfono")
            @Pattern(regexp = "^\\+?[0-9 ]{7,15}$", message = "Teléfono inválido") String phone,
            @NotNull(message = "Indica el número de mesas") @Min(value = 1, message = "Mínimo 1 mesa")
            @Max(value = 500, message = "Máximo 500 mesas") Integer tables) {
    }

    record LeadResponse(String message) {
    }
}
