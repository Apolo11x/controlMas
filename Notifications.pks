CREATE OR REPLACE PACKAGE notifications IS
    -- Declaration of constants
    c_version CONSTANT VARCHAR2(10) := '1.0';
    FUNCTION genFacturaContrato (p_id_contrato NUMBER) RETURN NUMBER;
    function insertarHistorialNotificacion (p_id_factura number, p_dias_mora number) return number;
    FUNCTION enviarMensajeWhatsApp(p_id_usuario NUMBER, p_plantilla VARCHAR2) RETURN NUMBER ;

    
END notifications;


