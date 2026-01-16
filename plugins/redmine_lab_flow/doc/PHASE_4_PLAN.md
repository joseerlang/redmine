Especificación Técnica: Redmine LabFlow (Fase 4 - Compliance & Data Integrity)
1. Objetivo
   Implementar controles de seguridad avanzados y flujos de trabajo de interoperabilidad para garantizar que los datos del laboratorio sean FAIR (Buscables, Accesibles, Interoperables y Reutilizables) y cumplan con los estándares internacionales de integridad.
2. Componentes de Integridad y Cumplimiento
   El plugin debe forzar la transparencia y la inmutabilidad de los registros críticos:
   • Firmas Electrónicas de Atestación: Implementar un flujo donde el cambio a estados finales (ej. "Completed") requiera una re-autenticación del usuario y la selección de un "Significado de la firma" (ej. Autoría, Revisión).
   • Audit Trail Avanzado: Extender el historial nativo de Redmine para capturar no solo el cambio, sino la "Razón del Cambio" de forma obligatoria para campos de resultados analíticos.
   • Interoperabilidad vía REST API: Configurar "puntos de entrada" protegidos para que instrumentos externos puedan publicar resultados directamente en los Assays, eliminando el error humano en la transcripción.
3. Metadatos de Calidad e i18n
   Se añaden campos específicos para la trazabilidad de la procedencia de los datos.
   Clave i18n
   Valor (en-US)
   Propósito
   label_attestation
   Attestation
   Certificación legal del firmante.
   label_reason_for_change
   Reason for Change
   Justificación obligatoria para auditorías.
   label_data_provenance
   Data Provenance
   Origen del dato (Manual vs. Instrumento).
   label_signature_meaning
   Signature Meaning
   Contexto de la firma electrónica.

--------------------------------------------------------------------------------
4. Instrucción para Claude Code (Prompt de Ejecución)
   Contexto: Desarrollador senior de Ruby on Rails especializado en seguridad y cumplimiento para Redmine 6.x.
   Tarea: Implementar la Fase 4 - Cumplimiento y Seguridad de Datos en el plugin redmine_lab_flow.
   Requisitos Técnicos:
1. Firma Electrónica: Implementar un before_save hook que, si un Assay cambia a estado "Verified" o "Completed", lance una ventana modal (View Hook) solicitando la contraseña del usuario y un campo de "Signature Meaning" (Lista: Authorship, Review, Approval).
2. Audit Trail Seguro: Modificar el formulario de edición para que, si el registro ya contiene datos en "Measured Value", el campo "Notes" (Razón del cambio) sea obligatorio para guardar los cambios.
3. Endpoint de Interoperabilidad: Crear un controlador API personalizado que permita a sistemas externos (usando un API Key) actualizar campos personalizados de un Assay específico basado en su Internal ID.
4. Validación de Procedencia: Añadir un campo oculto source_type que registre automáticamente si el dato entró por la interfaz web o por la API.
5. i18n: Actualizar config/locales/en.yml con terminología técnica de cumplimiento en inglés americano.
   Restricción: No utilizar "science" ni "sci". Utilizar el estándar de registros electrónicos para que el sistema sea capaz de producir copias completas y precisas para inspección de auditores.

--------------------------------------------------------------------------------
Valor Operativo de la Fase 4
• Reducción de Riesgos: La automatización de la ingesta de datos reduce significativamente la tasa de error por transcripción manual.
• Preparación para Auditorías: El sistema mantiene un registro inmutable y contemporáneo, lo que acelera la preparación de informes regulatorios y garantiza que los cambios no oscurezcan la información previa.
• Soberanía de Datos: Al utilizar formatos abiertos (vía API REST) y estándares FAIR, el laboratorio asegura que sus datos sean legibles tanto por humanos como por máquinas a largo plazo.
Analogía: Si las fases anteriores construyeron el laboratorio y lo dotaron de manuales e insumos, la Fase 4 es el oficial de cumplimiento y la cámara de seguridad. Asegura que nadie pueda alterar un resultado sin dejar rastro y que cada reporte entregado sea legalmente defendible ante una inspección, garantizando que el "quién, cuándo y por qué" sea tan sólido como el resultado técnico mismo.