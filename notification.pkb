
CREATE OR REPLACE PACKAGE BODY notifications IS

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

    BEGIN
        DBMS_OUTPUT.PUT_LINE('Generando facturación para el contrato: ' || p_id_contrato);
        OPEN cur_facturacion;
        LOOP
            FETCH cur_facturacion INTO v_fac;
            EXIT WHEN cur_facturacion%NOTFOUND;


            -- Generando facturas para cada mes desde la fecha de inicio hasta la fecha actual
            DECLARE
                TYPE t_facturas IS TABLE OF DATE;
                v_facturas t_facturas := t_facturas();
                v_fecha_factura DATE := v_fac.fecha_inicio;
            BEGIN
                WHILE v_fecha_factura <= SYSDATE LOOP
                    -- Agregar la fecha de factura a la colección
                    v_facturas.EXTEND;
                    v_facturas(v_facturas.COUNT) := v_fecha_factura;
                    -- Incrementar la fecha de factura según el intervalo de días del plan
                    --IF TO_CHAR(v_fecha_factura, 'MM-YYYY') = TO_CHAR(v_fac.fecha_inicio, 'MM-YYYY') THEN
                    --    v_fecha_factura := ADD_MONTHS(v_fecha_factura, 1);
                    --    v_fecha_factura := TRUNC(v_fecha_factura, 'MM') + (EXTRACT(DAY FROM v_fac.fecha_inicio) - 1);
                    --ELSE
                        v_fecha_factura := v_fecha_factura + v_fac.nro_dias;
                    --END IF;
                    -- v_fecha_factura := v_fecha_factura + v_fac.nro_dias;
                END LOOP;

                -- Mostrar todas las fechas de facturación generadas
                FOR i IN 1..v_facturas.COUNT LOOP
                    DBMS_OUTPUT.PUT_LINE('Id Contrato: ' || v_fac.id_contrato || ' Fecha: ' || TO_CHAR(v_facturas(i), 'YYYY-MM-DD'));
                END LOOP;

                -- Buscar las fechas de facturación existentes en la tabla cm_factura
                FOR i IN REVERSE 1..v_facturas.COUNT LOOP
                    SELECT COUNT(1)
                    INTO v_exists
                    FROM cm_factura f
                    WHERE f.id_contrato = v_fac.id_contrato
                      AND TO_CHAR(f.fecha, 'MM-YYYY') = TO_CHAR(v_facturas(i), 'MM-YYYY');

                    IF v_exists > 0 THEN
                        -- Eliminar la fecha de la colección si ya existe en la tabla cm_factura
                        v_facturas.DELETE(i);
                    END IF;
                END LOOP;

                -- Mostrar las fechas de facturación finales que serán procesadas
                FOR i IN 1..v_facturas.COUNT LOOP
                    DBMS_OUTPUT.PUT_LINE('Generando factura para Id Contrato: ' || v_fac.id_contrato || 
                                         ' Fecha: ' || TO_CHAR(v_facturas(i), 'YYYY-MM-DD'));
                    -- Aquí se puede agregar la lógica para insertar la factura en la tabla cm_factura
                     insert into cm_factura (id_contrato, fecha, valor,estado )
                     values (v_fac.id_contrato, v_facturas(i), v_fac.valor,'Pendiente');
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

    


    

END notifications;
