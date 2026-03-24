%% TFG - ANÁLISIS DE DEGRADACIÓN DEL PDOP POR MÁSCARA DE ELEVACIÓN
clear; clc; close all;

%% 1. CONFIGURACIÓN DEL ESCENARIO
filename = 'current.alm'; % Asegúrate de tener este archivo, es como he guardado el almanaque YUMA del día a probar
lat_obs = 42.39 * pi/180; % Marín (Latitud en radianes)
lon_obs = -8.70 * pi/180; % Marín (Longitud en radianes)
alt_obs = 10;            % Altura sobre el elipsoide (metros)

% Rango de máscaras a simular (Ángulo de corte del cilindro)
mascaras_deg = 0:2:80; % De 0 a 80 grados, cada 2 grados

% Tiempo de simulación: 24 horas cada 10 minutos
t_step = 600; 
time_vector = 0:t_step:86400; 

%% 2. LECTURA Y PROCESADO DEL ALMANAQUE
try
    alm = leer_yuma(filename);
    fprintf('Almanaque cargado: %d satélites GPS activos.\n', length(alm));
catch
    error('No se encuentra el archivo %s. Descárgalo de navcen.uscg.gov', filename);
end

%% 3. BUCLE DE SIMULACIÓN (DOP vs MÁSCARA)
media_PDOP = zeros(length(mascaras_deg), 1);

fprintf('Iniciando simulación de precisión... \n');

for k = 1:length(mascaras_deg)
    mask_rad = mascaras_deg(k) * pi/180;
    PDOP_diario = [];
    
    % Bucle temporal (un día entero)
    for t = time_vector
        [azimuts, elevaciones] = calcular_posiciones_sats(alm, t, lat_obs, lon_obs, alt_obs);
        
        % Filtrar por máscara (Simulación del Cilindro)
        visibles = elevaciones >= mask_rad;
        Az_visibles = azimuts(visibles);
        El_visibles = elevaciones(visibles);
        
        if length(Az_visibles) >= 4
            % Cálculo de la Matriz de Geometría (H)
            H = zeros(length(Az_visibles), 4);
            H(:,1) = cos(El_visibles) .* sin(Az_visibles); 
            H(:,2) = cos(El_visibles) .* cos(Az_visibles); 
            H(:,3) = sin(El_visibles);                     
            H(:,4) = 1;                                    
            
            try
                % Cálculo de la Matriz de Covarianza (Q) y PDOP
                Q = inv(H' * H);
                pdop_val = sqrt(Q(1,1) + Q(2,2) + Q(3,3));
            catch
                pdop_val = NaN; % Matriz singular (mala geometría)
            end
        else
            pdop_val = NaN; % Menos de 4 satélites (sin solución)
        end
        
        PDOP_diario = [PDOP_diario, pdop_val];
    end
    
    % Guardamos la media del PDOP para este ángulo de máscara
    % 'omitnan' ignora los momentos donde no hay cobertura
    media_PDOP(k) = mean(PDOP_diario, 'omitnan');
end

%% 4. REPRESENTACIÓN GRÁFICA (SOLO PRECISIÓN)
figure('Color', 'w', 'Name', 'Analisis de PDOP');

plot(mascaras_deg, media_PDOP, '-o', 'LineWidth', 2, 'Color', '#0072BD', 'MarkerFaceColor', 'w');

% Formato de la gráfica
ylabel('PDOP Medio (Dilución de Precisión)');
xlabel('Ángulo de Máscara de Elevación (Grados)');
title('Degradación de la Precisión GPS por Apantallamiento');
subtitle(['Simulación YUMA - Marín (' datestr(now) ')']);

grid on; 
xlim([0 80]);
ylim([0 20]); % Ajusta este límite según tus resultados para ver detalle

% Líneas de referencia de calidad
yline(6, 'r--', 'Límite de Servicio Estándar (PDOP=6)');
legend('PDOP Medio Diario', 'Umbral de Calidad', 'Location', 'NorthWest');

%% --- FUNCIONES AUXILIARES (KEPLER Y YUMA) ---
function [Az, El] = calcular_posiciones_sats(alm, t, lat_u, lon_u, alt_u)
    % Constantes WGS84
    mu = 3.986005e14;  
    Omega_e_dot = 7.2921151467e-5; 
    
    Az = []; El = [];
    
    % Posición Usuario ECEF
    R_earth = 6371000; 
    xu = (R_earth+alt_u)*cos(lat_u)*cos(lon_u);
    yu = (R_earth+alt_u)*cos(lat_u)*sin(lon_u);
    zu = (R_earth+alt_u)*sin(lat_u);
    
    for i = 1:length(alm)
        s = alm(i);
        a = s.sqrta^2;       
        n0 = sqrt(mu/a^3);   
        t_k = t - s.toe;     
        
        if t_k > 302400, t_k = t_k - 604800; end
        if t_k < -302400, t_k = t_k + 604800; end
        
        M_k = s.M0 + n0 * t_k; 
        E_k = M_k; 
        for iter = 1:10
            E_k = M_k + s.e * sin(E_k);
        end
        
        v_k = atan2(sqrt(1-s.e^2)*sin(E_k), cos(E_k)-s.e); 
        Phi_k = v_k + s.omega; 
        
        r_k = a * (1 - s.e*cos(E_k)); 
        x_prime = r_k * cos(Phi_k);
        y_prime = r_k * sin(Phi_k);
        
        Omega_k = s.Omega0 + (s.OmegaDot - Omega_e_dot)*t_k - Omega_e_dot*s.toe;
        
        xs = x_prime * cos(Omega_k) - y_prime * cos(s.i) * sin(Omega_k);
        ys = x_prime * sin(Omega_k) + y_prime * cos(s.i) * cos(Omega_k);
        zs = y_prime * sin(s.i);
        
        dx = xs - xu; dy = ys - yu; dz = zs - zu;
        
        sl = sin(lat_u); cl = cos(lat_u);
        so = sin(lon_u); co = cos(lon_u);
        
        R = [-so, co, 0; -sl*co, -sl*so, cl; cl*co, cl*so, sl];
        enu = R * [dx; dy; dz];
        
        dist = sqrt(enu(1)^2 + enu(2)^2 + enu(3)^2);
        el_rad = asin(enu(3)/dist);
        az_rad = atan2(enu(1), enu(2));
        
        Az = [Az; az_rad];
        El = [El; el_rad];
    end
end

function alm = leer_yuma(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('Error abriendo fichero'); end
    alm = []; idx = 0;
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'ID')
            idx = idx + 1;
            alm(idx).id = sscanf(line, 'ID: %d');
        elseif contains(line, 'Health'), alm(idx).health = sscanf(line, 'Health: %d');
        elseif contains(line, 'Eccentricity'), alm(idx).e = sscanf(line, 'Eccentricity: %f');
        elseif contains(line, 'Time of Applicability'), alm(idx).toe = sscanf(line, 'Time of Applicability(s): %f');
        elseif contains(line, 'Orbital Inclination'), alm(idx).i = sscanf(line, 'Orbital Inclination(rad): %f');
        elseif contains(line, 'Rate of Right Ascen'), alm(idx).OmegaDot = sscanf(line, 'Rate of Right Ascen(r/s): %e');
        elseif contains(line, 'SQRT(A)'), alm(idx).sqrta = sscanf(line, 'SQRT(A)  (m 1/2): %f');
        elseif contains(line, 'Right Ascen at Week'), alm(idx).Omega0 = sscanf(line, 'Right Ascen at Week(rad): %f');
        elseif contains(line, 'Argument of Perigee'), alm(idx).omega = sscanf(line, 'Argument of Perigee(rad): %f');
        elseif contains(line, 'Mean Anom'), alm(idx).M0 = sscanf(line, 'Mean Anom(rad): %f');
        end
    end
    fclose(fid);
    validos = [alm.health] == 0;
    alm = alm(validos);
end