package pe.platter.leads.infrastructure;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import pe.platter.leads.domain.Lead;

public interface LeadRepository extends JpaRepository<Lead, UUID> {
}
