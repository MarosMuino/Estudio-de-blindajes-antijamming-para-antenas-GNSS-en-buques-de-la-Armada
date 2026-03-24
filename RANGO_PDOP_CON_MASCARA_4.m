%% TFG - SIMULACIÓN DE PDOP CON CAVIDAD ANTI-JAMMING (MÁSCARA Variable)
clc; clear; close all;

% --- 1. CONFIGURACIÓN DEL ESCENARIO ---
lat_rx = 57.5;      % Latitud Báltico
lon_rx = 19.5;      % Longitud Báltico

% Máscara física impuesta por el cilindro según tu diseño, podemos
% establecer cualquier valor para analizar
mascara_cavidad = 30; 
fprintf('La cavidad cilíndrica impone una máscara física de %.1f grados.\n', mascara_cavidad);

% Tiempo: 1 semana en pasos de 15 min
paso_s = 900; 
dias = 7;
t_semana = 0 : paso_s : (dias * 24 * 3600);
num_pasos = length(t_semana);

% Matrices para guardar históricos
PDOP_historico = zeros(1, num_pasos);
Sats_Visibles_historico = zeros(1, num_pasos);

% --- 2. BUCLE TEMPORAL ---
for i = 1:num_pasos
    
    % =====================================================================
    % ZONA DE TUS FUNCIONES REALES (YUMA + IS-GPS-200)
    % Aquí deberías llamar a tus funciones de tu estudio anterior.
    %
    % [sat_x, sat_y, sat_z] = propagar_orbitas(constelacion, t_semana(i));
    % [az_todos, el_todos] = ecef2azel(sat_x, sat_y, sat_z, lat_rx, lon_rx, 0);
    % =====================================================================
    
    % --- INICIO BLOQUE SIMULADO (Borrar cuando uses tus funciones reales) ---
    % Simulamos que la constelación tiene 12 satélites sobre nuestro hemisferio
    num_sats_cielo = 12;
    az_todos = rand(1, num_sats_cielo) * 360; 
    el_todos = rand(1, num_sats_cielo) * 90; % Elevaciones entre 0 y 90 grados
    % --- FIN BLOQUE SIMULADO ---
    
    % --- 3. EL FILTRO CRÍTICO (El efecto del Cilindro) ---
    % Solo pasan los satélites cuya elevación supera los 27º
    idx_visibles = find(el_todos >= mascara_cavidad);
    
    az_visibles = az_todos(idx_visibles);
    el_visibles = el_todos(idx_visibles);
    
    Sats_Visibles_historico(i) = length(az_visibles);
    
    % --- 4. CONSTRUIR MATRIZ H Y CALCULAR PDOP ---
    if length(az_visibles) >= 4 
        H = zeros(length(az_visibles), 4);
        for s = 1:length(az_visibles)
            az_rad = deg2rad(az_visibles(s));
            el_rad = deg2rad(el_visibles(s));
            H(s, 1) = -cos(el_rad) * sin(az_rad);
            H(s, 2) = -cos(el_rad) * cos(az_rad);
            H(s, 3) = -sin(el_rad);
            H(s, 4) = 1;
        end
        
        Q = inv(H' * H);
        PDOP_historico(i) = sqrt(Q(1,1) + Q(2,2) + Q(3,3));
    else
        PDOP_historico(i) = NaN; % Pérdida de servicio (menos de 4 satélites)
    end
end

% --- 5. VISUALIZACIÓN ---
PDOP_medio = mean(PDOP_historico, 'omitnan');
Sats_medios = mean(Sats_Visibles_historico);

fprintf('=== RESULTADOS CON MÁSCARA %.fº ===\n', mascara_cavidad);
fprintf('Satélites medios visibles: %.1f\n', Sats_medios);
fprintf('PDOP Medio: %.2f\n', PDOP_medio);

figure('Color', 'w', 'Position', [100 100 900 400]);
plot(t_semana / 3600, PDOP_historico, 'b-', 'LineWidth', 1);
hold on;
yline(PDOP_medio, 'r-', 'LineWidth', 2, 'Label', sprintf('PDOP Medio: %.2f', PDOP_medio));
grid on;
title(sprintf('Evolución Semanal del PDOP con Cavidad Anti-Jamming (Máscara %dº)', mascara_cavidad), 'FontSize', 12);
xlabel('Tiempo (Horas)', 'FontSize', 11);
ylabel('Valor PDOP', 'FontSize', 11);
ylim([0 15]); % Límite visual para que no se dispare si hay picos
xlim([0 24*dias]);
