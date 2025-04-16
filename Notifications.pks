CREATE OR REPLACE PACKAGE notifications IS
    -- Declaration of constants
    c_version CONSTANT VARCHAR2(10) := '1.0';
    FUNCTION genFacturaContrato (p_id_contrato NUMBER) RETURN NUMBER;
    -- FUNCTION genNotificacionContrato (p_id_contrato NUMBER) RETURN NUMBER;
    --function calcularDiasMora (p_id_contrato NUMBER) RETURN NUMBER;
    
END notifications;


