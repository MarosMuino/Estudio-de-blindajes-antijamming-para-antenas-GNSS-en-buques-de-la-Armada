%% TFG: GENERADOR AUTOMÁTICO DE TABLAS DE PRECISIÓN 
% Este script procesa mensajes GGA y GSA para calcular todas las estadísticas
% de DOP, Satélites y Errores ECEF (Min, Max, Mean, Std, RMS).

clc; clear; close all;

% --- RUTA DE TU ARCHIVO ---
filename = 'C:\Users\marco\OneDrive\Escritorio\25-26\TFG\Grabaciones\22tarde1.ubx';

fid = fopen(filename, 'rt');
if fid == -1
    error('No se pudo abrir el archivo %s.', filename);
end

% Variables para almacenar datos
Lat_all = []; Lon_all = []; Alt_all = []; 
Sats_all = []; PDOP_all = []; HDOP_all = []; VDOP_all = [];

disp('Procesando archivo NMEA buscando tramas GGA y GSA...');
while ~feof(fid)
    line = fgetl(fid);
    
    if length(line) < 6 || line(1) ~= '$'
        continue;
    end
    
    parts = split(line, {',', '*'});
    type = line(4:6); % Extraemos si es GGA o GSA
    
    % --- 1. PROCESAR MENSAJES GGA (Posición y Satélites) ---
    if strcmp(type, 'GGA') && length(parts) >= 11
        if ~isempty(parts{3}) && ~isempty(parts{5}) && ~isempty(parts{8})
            % Número de satélites en uso
            Sats_all(end+1) = str2double(parts{8});
            
            % Latitud
            lat_deg = str2double(parts{3}(1:2));
            lat_min = str2double(parts{3}(3:end));
            lat = lat_deg + (lat_min / 60);
            if strcmp(parts{4}, 'S'), lat = -lat; end
            
            % Longitud
            lon_deg = str2double(parts{5}(1:3));
            lon_min = str2double(parts{5}(4:end));
            lon = lon_deg + (lon_min / 60);
            if strcmp(parts{6}, 'W'), lon = -lon; end
            
            % Altitud
            alt = str2double(parts{10});
            
            Lat_all(end+1) = lat;
            Lon_all(end+1) = lon;
            Alt_all(end+1) = alt;
        end
        
    % --- 2. PROCESAR MENSAJES GSA (Parámetros DOP) ---
    elseif strcmp(type, 'GSA') && length(parts) >= 18
        if ~isempty(parts{16}) && ~isempty(parts{17}) && ~isempty(parts{18})
            PDOP_all(end+1) = str2double(parts{16});
            HDOP_all(end+1) = str2double(parts{17});
            VDOP_all(end+1) = str2double(parts{18});
        end
    end
end
fclose(fid);

if isempty(Lat_all)
    error('No se encontraron datos. Asegúrate de que el log contiene texto NMEA.');
end

% Filtrar posibles NaNs por fallos de lectura
PDOP_all = PDOP_all(~isnan(PDOP_all));
HDOP_all = HDOP_all(~isnan(HDOP_all));
VDOP_all = VDOP_all(~isnan(VDOP_all));
Sats_all = Sats_all(~isnan(Sats_all));

disp('Calculando errores ECEF...');
% Parámetros WGS84
a = 6378137.0; 
e2 = 0.00669437999014; 

phi = deg2rad(Lat_all);
lam = deg2rad(Lon_all);
h = Alt_all;

N = a ./ sqrt(1 - e2 .* sin(phi).^2);
X_ecef = (N + h) .* cos(phi) .* cos(lam);
Y_ecef = (N + h) .* cos(phi) .* sin(lam);
Z_ecef = (N .* (1 - e2) + h) .* sin(phi);

% Referencia: media de las posiciones
X_ref = mean(X_ecef);
Y_ref = mean(Y_ecef);
Z_ref = mean(Z_ecef);

eECEF_x = X_ecef - X_ref;
eECEF_y = Y_ecef - Y_ref;
eECEF_z = Z_ecef - Z_ref;
eECEF_tot = sqrt(eECEF_x.^2 + eECEF_y.^2 + eECEF_z.^2);

% --- FUNCIÓN PARA CALCULAR ESTADÍSTICAS ---
calc_stats = @(data) [min(data), max(data), mean(data), std(data), sqrt(mean(data.^2))];

stats_VDOP = calc_stats(VDOP_all);
stats_HDOP = calc_stats(HDOP_all);
stats_PDOP = calc_stats(PDOP_all);
stats_Sats = calc_stats(Sats_all);
stats_ex   = calc_stats(eECEF_x);
stats_ey   = calc_stats(eECEF_y);
stats_ez   = calc_stats(eECEF_z);
stats_etot = calc_stats(eECEF_tot);

% =========================================================================
% --- IMPRESIÓN DE LA TABLA (FORMATO PAPER) ---
% =========================================================================
fprintf('\n\n=========================================================================================\n');
fprintf('  Basic quantitative statistics of the analyzed parameters\n');
fprintf('=========================================================================================\n');
fprintf('%-15s | %-4s | %10s | %10s | %10s | %10s | %10s\n', 'Parameter', 'Unit', 'Minimum', 'Maximum', 'Mean', 'Std Dev', 'RMS');
fprintf('-----------------------------------------------------------------------------------------\n');

% Imprimir DOPs y Satélites (formato decimal estándar)
fprintf('%-15s | %-4s | %10.2f | %10.2f | %10.2f | %10.2f | %10.2f\n', 'VDOP', '-', stats_VDOP);
fprintf('%-15s | %-4s | %10.2f | %10.2f | %10.2f | %10.2f | %10.2f\n', 'HDOP', '-', stats_HDOP);
fprintf('%-15s | %-4s | %10.2f | %10.2f | %10.2f | %10.2f | %10.2f\n', 'PDOP', '-', stats_PDOP);
fprintf('%-15s | %-4s | %10.0f | %10.0f | %10.2f | %10.2f | %10.2f\n', 'Satellites', '-', stats_Sats);

% Imprimir Errores ECEF (formato científico para que quede como el paper)
fprintf('%-15s | %-4s | %10.2e | %10.2e | %10.2e | %10.2e | %10.2e\n', 'eECEF_X', 'm', stats_ex);
fprintf('%-15s | %-4s | %10.2e | %10.2e | %10.2e | %10.2e | %10.2e\n', 'eECEF_Y', 'm', stats_ey);
fprintf('%-15s | %-4s | %10.2e | %10.2e | %10.2e | %10.2e | %10.2e\n', 'eECEF_Z', 'm', stats_ez);
fprintf('%-15s | %-4s | %10.2e | %10.2e | %10.2e | %10.2e | %10.2e\n', 'eECEF_total', 'm', stats_etot);
fprintf('=========================================================================================\n\n');
