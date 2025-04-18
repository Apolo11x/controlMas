
CREATE OR REPLACE PACKAGE BODY notifications IS

-- declaracion de tipos de datos
    TYPE t_factura IS RECORD (
        id_contrato number,
        id_plan number,
        id_factura number,
        fecha DATE,
        dias_mora NUMBER
    );
    
    TYPE t_facturas IS TABLE OF t_factura;

    -- funcion que genera la factura de un contrato especifico 
    FUNCTION genFacturaContrato (p_id_contrato NUMBER) RETURN NUMBER IS
        

        CURSOR cur_facturacion IS
            SELECT c.id_contrato, c.id_plan, c.id_usuario, c.fecha_inicio, c.fecha_fin, c.estado, 
                   p.descripcion, p.nro_dias, p.valor, p.estado AS estado_plan
            FROM cm_contrato c
            JOIN cm_plan p ON c.id_plan = p.id_plan
            WHERE c.estado = 'Activo' AND p.estado = 'Activo' 
              AND c.id_contrato = p_id_contrato
              AND (c.fecha_fin IS NULL OR c.fecha_fin > SYSDATE)
              AND c.fecha_inicio <= SYSDATE;

        v_fac cur_facturacion%ROWTYPE; 
        v_exists NUMBER;
        v_rtaHistorial NUMBER:=0;

    BEGIN
        DBMS_OUTPUT.PUT_LINE('Generando facturación para el contrato: ' || p_id_contrato);
        OPEN cur_facturacion;
        LOOP
            FETCH cur_facturacion INTO v_fac;
            EXIT WHEN cur_facturacion%NOTFOUND;

            -- Generando facturas para cada mes desde la fecha de inicio hasta la fecha actual
            DECLARE
                -- Definición de la colección para almacenar las fechas de facturación              
                v_facturas t_facturas := t_facturas();
                v_facNotificar t_facturas := t_facturas();
                v_fecha_factura DATE := v_fac.fecha_inicio;
                iNot number := 1;
            BEGIN
                WHILE v_fecha_factura <= SYSDATE LOOP
                    -- Agregar la fecha de factura a la colección
                    v_facturas.EXTEND;
                    v_facturas(v_facturas.COUNT).id_contrato := v_fac.id_contrato;
                    v_facturas(v_facturas.COUNT).id_plan := v_fac.id_plan;
                    v_facturas(v_facturas.COUNT).fecha := v_fecha_factura;
                    v_facturas(v_facturas.COUNT).dias_mora := trunc(sysdate - v_fecha_factura); -- Placeholder for dias_mora
                    -- Calcular la próxima fecha de facturación
                    v_fecha_factura := v_fecha_factura + v_fac.nro_dias;
                    -- verificar que la fecha de factura no caiga en el mismo mes de la anterior factura se ajusta al siguiente mes y al mismo dia de la fecha de inciio del contrato   
                    IF EXTRACT(MONTH FROM v_facturas(v_facturas.COUNT).fecha) = EXTRACT(MONTH FROM v_fecha_factura) THEN
                        v_fecha_factura := ADD_MONTHS(v_fecha_factura, 1);
                        -- colocar a la fecha de factura el mismo dia de la fecha de inciio 
                        v_fecha_factura := TRUNC(v_fecha_factura, 'MM') + (EXTRACT(DAY FROM v_fac.fecha_inicio) - 1);
                    END IF;

                    -- Calcular la proxima factura despues de la fecha actual sysdate y fecha factua es mayor que sysdatge 
                    IF v_fecha_factura > SYSDATE THEN
                        v_facturas.EXTEND;
                        v_facturas(v_facturas.COUNT).id_contrato := v_fac.id_contrato;
                        v_facturas(v_facturas.COUNT).id_plan := v_fac.id_plan;
                        v_facturas(v_facturas.COUNT).fecha := v_fecha_factura;
                        v_facturas(v_facturas.COUNT).dias_mora := trunc(sysdate - v_fecha_factura); -- Placeholder for dias_mora
                    END IF;

                END LOOP;

                -- Verificar si la fecha de factura ya existe en la tabla cm_factura
                -- y eliminar de la coleccion las fechas que ya existen
                FOR i IN REVERSE 1..v_facturas.COUNT LOOP
                    SELECT COUNT(1) INTO v_exists
                    FROM cm_factura f
                    WHERE f.id_contrato = v_fac.id_contrato
                      AND TO_CHAR(f.fecha, 'MM-YYYY') = TO_CHAR(v_facturas(i).fecha, 'MM-YYYY') 
                      and f.ESTADO!='Pagada';

                      -- mostraer en pantalla la fecha de la factura a procesar y si existe
                    DBMS_OUTPUT.PUT_LINE('Fecha de factura a procesar: ' || TO_CHAR(v_facturas(i).fecha, 'YYYY-MM-DD') || 
                                         ' - Existe en cm_factura: ' || v_exists);
                    v_facNotificar.EXTEND;
                    v_facNotificar(iNot).id_contrato := v_facturas(i).id_contrato;
                    v_facNotificar(iNot).fecha := v_facturas(i).fecha;
                    v_facNotificar(iNot).dias_mora := v_facturas(i).dias_mora;
                    v_facNotificar(iNot).id_plan := v_facturas(i).id_plan;
                    v_facNotificar(iNot).id_factura := 0;

                    IF v_exists > 0 THEN
                        -- Eliminar la fecha de la colección si ya existe en la tabla cm_factura
                        -- mostrar la factura a eliminar 
/*                        DBMS_OUTPUT.PUT_LINE('Eliminando factura para Id Contrato: ' || v_fac.id_contrato || 
                                         ' Fecha: ' || TO_CHAR(v_facturas(i).fecha, 'YYYY-MM-DD') || 
                                         ' Días de Mora: ' || NVL(v_facturas(i).dias_mora, 0));
*/                        -- Selecciona la factura de acuerdo al id y la fecha facturacion y la guarda en la coleccion
                        SELECT f.id_factura INTO v_facNotificar(iNot).id_factura
                        FROM cm_factura f
                        WHERE f.id_contrato = v_facNotificar(iNot).id_contrato and 
                              TO_CHAR(f.fecha, 'MM-YYYY') = TO_CHAR(v_facNotificar(iNot).fecha, 'MM-YYYY') and
                              f.ESTADO!='Pagada';
                        -- eliminar la fecha de la coleccion                     
                        v_facturas.DELETE(i);
                    ELSE
                        --mostrar factura para notificacion
/*                        DBMS_OUTPUT.PUT_LINE('NOTIFICACION: Factura para Id Contrato: ' || v_fac.id_contrato || 
                                         ' Fecha: ' || TO_CHAR(v_facturas(i).fecha, 'YYYY-MM-DD') || 
                                         ' Días de Mora: ' || NVL(v_facturas(i).dias_mora, 0));
*/
                        NULL;

                    END IF;
                    iNot := iNot + 1;  
                END LOOP;

                -- mostrar cantidad de facuras en la coleccion
                DBMS_OUTPUT.PUT_LINE('Cantidad de facturas a Notificar : ' || v_facNotificar.COUNT);

                -- Mostrar las fechas de facturación finales que serán procesadas
                -- insertamos la facturacion si hay lugar 
                FOR i IN 1..v_facturas.COUNT  LOOP
                    if i<v_facturas.COUNT then 
                        DBMS_OUTPUT.PUT_LINE(' Generando factura para Id Contrato: ' || v_fac.id_contrato || 
                                             ' Fecha: ' || TO_CHAR(v_facturas(i).fecha, 'YYYY-MM-DD') || 
                                             ' Días de Mora: ' || NVL(v_facturas(i).dias_mora, 0));
                        --null;
                        insert into cm_factura (id_contrato, fecha, valor,estado )
                        values (v_fac.id_contrato, v_facturas(i).fecha, v_fac.valor,'Pendiente') returnING id_factura into v_facNotificar(i).id_factura;
                    end if ;    
                END LOOP;

                -- muestre las facturas a notificar en v_facNotificar
                DBMS_OUTPUT.PUT_LINE('Facturas a Notificar: '|| v_facNotificar.COUNT);
                FOR i IN REVERSE 1..v_facNotificar.COUNT LOOP
                    DBMS_OUTPUT.PUT_LINE(' Id Contrato: ' || v_facNotificar(i).id_contrato || 
                                         ' Fecha: ' || TO_CHAR(v_facNotificar(i).fecha, 'YYYY-MM-DD') || 
                                         ' Días de Mora: ' || NVL(v_facNotificar(i).dias_mora, 0) || 
                                         ' Id Factura: ' || v_facNotificar(i).id_factura);
                    -- seleccionar el registro en notifiacion de acuerdo al plan
                    SELECT count(*) INTO v_exists
                    FROM cm_notificacion n
                    WHERE n.id_plan = v_facNotificar(i).id_plan and
                          n.NUM_DIAS = v_facNotificar(i).dias_mora and 
                          n.estado = 'Activo';
                    
                    if v_exists > 0 THEN
                        -- verificar si la notificacion se encuentra en el historial de notificacion por el id de la factura 
                        v_rtaHistorial := insertarHistorialNotificacion(v_facNotificar(i).id_factura, v_facNotificar(i).dias_mora);
                        dbms_output.put_line('Rta Historial: ' || v_rtaHistorial);

                        IF v_rtaHistorial = 1 THEN
                                DBMS_OUTPUT.PUT_LINE('Notificación generada para la factura: ' || v_facNotificar(i).id_factura);
                        ELSif v_rtaHistorial = -1 THEN
                                DBMS_OUTPUT.PUT_LINE('Error en la Notificacion para la factura: ' || v_facNotificar(i).id_factura);
                        ELSIF   v_rtaHistorial = 0 THEN
                                DBMS_OUTPUT.PUT_LINE('La notificacion ya existe para la factura:: ' || v_facNotificar(i).id_factura);
                        END IF;
                    end if;    
                END LOOP;

            END; -- Close the DECLARE block
        END LOOP; -- Close the outer loop
        commit;

        -- Cerrar el cursor
        IF cur_facturacion%ISOPEN THEN
            CLOSE cur_facturacion;
        END IF;

        RETURN 0; -- Retornar un valor de éxito
    END genFacturaContrato;

    function insertarHistorialNotificacion (p_id_factura number, p_dias_mora number) return number is
        -- Factura
        v_fechaFactura cm_factura.fecha%TYPE;
        v_vlrFactura cm_factura.valor%TYPE; 
        -- Contrato
        v_idContrato cm_contrato.id_contrato%TYPE;
        -- Plan 
        v_idPlan cm_plan.id_plan%TYPE;
        v_descPlan cm_plan.descripcion%TYPE;
        v_vlrPlan cm_plan.valor%TYPE;

        -- Notificacion
        v_idNotificacion cm_notificacion.id_notificacion%TYPE;
        v_plantillaPlan cm_notificacion.plantilla%TYPE;
        -- Usuario
        v_idUsuario cm_usuario.id_usuario%TYPE; 
        v_nomUsuario cm_usuario.nombre%TYPE;

        v_exists number := 0; -- verificar si existe en el historial de notificaciones

    BEGIN
        -- verificar que la notificacion no se haya generado y se encuentre en el historial de notificaciones 
        SELECT count(*) INTO v_exists
        FROM cm_historial_notificacion h
        WHERE h.id_factura = p_id_factura and 
              h.estado = 'Notificada';
        IF v_exists > 0 THEN    
            DBMS_OUTPUT.PUT_LINE('La notificación ya fue generada para la factura: ' || p_id_factura);
            RETURN 0; -- Retornar un valor de error
        ELSE 
            DBMS_OUTPUT.PUT_LINE('Generando notificación para la factura: ' || p_id_factura);
            -- Seleccionar la factura, el plan, el usuario de acuerdo al id de la factura
            if p_id_factura = 0 then
                null;
            else           
                SELECT f.fecha, f.valor, f.id_contrato, c.id_plan, p.descripcion, p.valor, n.ID_NOTIFICACION, n.plantilla, u.id_usuario, u.nombre
                INTO v_fechaFactura, v_vlrFactura, v_idContrato, v_idPlan, v_descPlan, v_vlrPlan, v_idNotificacion, v_plantillaPlan, v_idUsuario, v_nomUsuario
                FROM cm_factura f
                JOIN cm_contrato c ON f.id_contrato = c.id_contrato
                JOIN cm_plan p ON c.id_plan = p.id_plan 
                join cm_notificacion n ON p.id_plan = n.id_plan
                JOIN cm_usuario u ON c.id_usuario = u.id_usuario
                WHERE f.id_factura = p_id_factura and n.num_dias = p_dias_mora;
            end if;

            -- reemplazar los datos de la plantilla con las variables 
            
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<NOMUSU>', v_nomUsuario);
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<IDCON>', v_idContrato);
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<IDFAC>', p_id_factura);
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<FECFAC>', TO_CHAR(v_fechaFactura, 'YYYY-MM-DD'));
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<VALFAC>', v_vlrFactura);
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<VALPLAN>', v_vlrPlan);
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<DESCPLAN>', v_descPlan);
            v_plantillaPlan := REPLACE(v_plantillaPlan, '<DIASMORA>', p_dias_mora);
            
            -- IMPRMIR LA PLANTILLA 
            DBMS_OUTPUT.PUT_LINE('Plantilla de notificación: ' || v_plantillaPlan);

 



            -- Verificar si la notificación ya existe en el historial de notificaciones     
        END IF;

        -- Insertar en la tabla de historial de notificaciones
        --INSERT INTO cm_historial_notificacion (id_factura, id_notificacion, fecha, estado)
        --VALUES (p_id_factura, id_notificacion, SYSDATE, 'Notificada');
        
        --COMMIT;
        
        RETURN 1; -- Retornar un valor de éxito
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error al insertar en el historial de notificación: ' || SQLERRM);
            ROLLBACK;
            RETURN 0; -- Retornar un valor de error
    END insertarHistorialNotificacion;

    FUNCTION enviarMensajeWhatsApp(p_id_usuario NUMBER, p_plantilla VARCHAR2) RETURN NUMBER IS
        v_numero_telefono cm_usuario.telefono%TYPE;
        v_url VARCHAR2(4000);
        v_response VARCHAR2(4000);
    BEGIN
        -- Obtener el número de teléfono del usuario
        SELECT trrim(telefono)
        INTO v_numero_telefono
        FROM cm_usuario
        WHERE id_usuario = p_id_usuario;

        -- Validar que el número de teléfono no sea nulo
        IF v_numero_telefono IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('El usuario no tiene un número de teléfono registrado.');
            RETURN -1; -- Retornar un valor de error
        END IF;

        -- Construir la URL para enviar el mensaje de WhatsApp
        -- http://167.86.78.186/SendMessage.php?receiver=%NUMBER%&message=%MESSAGE%
        v_url := 'http://167.86.78.186/SendMessage.php?receiver=' || trim(v_numero_telefono) || '&message=' || UTL_URL.ESCAPE(trim(p_plantilla));

        -- Simular el envío del mensaje (en un entorno real, se usaría una API HTTP)
        DBMS_OUTPUT.PUT_LINE('Enviando mensaje a través de WhatsApp: ' || v_url);

        -- Implementar la llamada HTTP usando UTL_HTTP
        DECLARE
            v_http_request  UTL_HTTP.req;
            v_http_response UTL_HTTP.resp;
        BEGIN
            -- Crear la solicitud HTTP
            v_http_request := UTL_HTTP.begin_request(v_url, 'GET');
            
            -- Enviar la solicitud y obtener la respuesta
            v_http_response := UTL_HTTP.get_response(v_http_request);
            
            -- Leer el cuerpo de la respuesta
            UTL_HTTP.read_text(v_http_response, v_response);
            
            -- Cerrar la respuesta HTTP
            UTL_HTTP.end_response(v_http_response);
            
            DBMS_OUTPUT.PUT_LINE('Respuesta del servidor: ' || v_response);
        EXCEPTION
            WHEN UTL_HTTP.end_of_body THEN
                UTL_HTTP.end_response(v_http_response);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error en la llamada HTTP: ' || SQLERRM);
        END;

        RETURN 1; -- Retornar un valor de éxito
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Usuario no encontrado con ID: ' || p_id_usuario);
            RETURN -1; -- Retornar un valor de error
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error al enviar el mensaje de WhatsApp: ' || SQLERRM);
            RETURN 0; -- Retornar un valor de error
    END enviarMensajeWhatsApp;




   

END notifications;
