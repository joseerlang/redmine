Especificación Técnica: Redmine LabFlow (Fase 3 - LIMS Core)
1. Objetivo
   Implementar la infraestructura para la gestión de recursos físicos (reactivos y equipos) y automatizar el flujo de trabajo operativo de las muestras y ensayos, garantizando la trazabilidad metrológica y el cumplimiento de normativas de integridad de datos.
2. Componentes de Automatización y Workflow
   El plugin debe forzar transiciones de estado basadas en la lógica de negocio para evitar el "caos incontrolable" en el procesamiento de datos.
   • Estados del Ciclo de Vida (Trackers: Sample/Assay): El plugin creará e instalará automáticamente los siguientes estados de flujo:
  1. Accessioned: Registro inicial del ítem.
  2. In Analysis: Fase de ejecución técnica.
  3. QC Pending: Validación técnica obligatoria antes de liberar resultados.
  4. Completed / Archived: Finalización inmutable del registro.
     • Permisos de Transición: Solo roles específicos (ej. Reviewer) podrán mover registros a "Completed", asegurando la accountability (rendición de cuentas).
3. Gestión de Inventario y Equipos
   Se implementará un módulo de inventario nativo para evitar retrasos por falta de suministros críticos.
   • Tabla lab_reagents: Seguirá el modelo de gestión de suministros para rastrear números de lote y fechas de expiración.
   • Campos de Metadatos Estructurados (Custom Fields):
   ◦ Lot Number: Identificación unívoca del material utilizado.
   ◦ Expiration Date: Campo de fecha para alertas automáticas de caducidad.
   ◦ Equipment ID: Lista de valores para vincular el ensayo con el instrumento utilizado.
4. Requisitos de Cumplimiento (Compliance)
   Para alinearse con la normativa FDA 21 CFR Part 11, el sistema debe garantizar que los registros sean confiables y que los cambios sean trazables.
   • Audit Trail Seguro: Implementar un registro inmutable de quién, cuándo y qué cambió en cada campo, incluyendo los valores anteriores y posteriores.
   • Reason for Change: El plugin inyectará un campo obligatorio de "Razón del cambio" cada vez que se edite un registro después de su creación inicial.

--------------------------------------------------------------------------------
5. Instrucciones para Claude Code (Prompt de Ejecución)
   Context: Senior Ruby on Rails developer working on the redmine_lab_flow plugin for Redmine 6.x (Rails 7 context).
   Task: Implement Phase 3 - LIMS Core & Inventory Management.
   Technical Requirements:
1. Database Expansion: Generate a migration for lab_reagents (name:string, lot_number:string, expiration_date:date, quantity:float) and lab_equipment (name:string, serial_number:string, calibration_due:date).
2. Workflow Automation: Create a script to provision the Issue Statuses: "Accessioned", "In Analysis", "QC Pending", and "Completed". Assign these to the "Sample" and "Assay" trackers.
3. Metadata Provisioning: Programmatically create IssueCustomFields:
   ◦ "Lot Number" (Format: Key/Value List, associated with reagents).
   ◦ "Equipment ID" (Format: List, dynamically populated from lab_equipment).
   ◦ "Calibration Due" (Format: Date, associated with equipment).
4. Business Logic (Validations): Implement a model-level validation that prevents an "Assay" from being moved to "Completed" if the associated "Lot Number" is linked to a reagent with an expiration_date in the past.
5. Audit Trail Integration: Use a View Hook to require a notes entry (Reason for Change) whenever an Issue with the "Assay" tracker is modified, ensuring it is captured in the Redmine journal.
6. i18n Implementation: Update config/locales/en.yml with American English labels for all new fields and statuses.
   Constraint: Avoid using the word "science" or "scientific". Use terms like "Laboratory", "Inventory", and "Reagent". Ensure compatibility with Rails 7 and Redmine 6.x permissions.

--------------------------------------------------------------------------------
Valor Operativo de la Fase 3
Esta aproximación centraliza la narrativa del flujo de trabajo con los datos estructurados de las muestras, lo que permite un ahorro promedio de 9 horas semanales por investigador al automatizar la generación de reportes y la búsqueda de datos. Al forzar reglas de negocio (como no usar reactivos caducados), se reducen significativamente los errores de transcripción y se mejora el rendimiento experimental en un 30%.
Analogía: Si la Fase 1 fue la estructura del edificio y la Fase 2 el manual de protocolos, la Fase 3 es la instalación de los suministros y los sistemas de control de acceso. Ahora el laboratorio no solo tiene un lugar donde trabajar, sino que sabe exactamente cuánto material le queda y asegura que nadie pueda saltarse un paso de validación técnica antes de entregar un resultado final.