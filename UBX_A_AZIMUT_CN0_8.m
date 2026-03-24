filename = []; %depende de donde se guarde el archivo UBX a analizar 
% =========================================================================
% Script para leer y graficar Elevación y C/N0 desde tramas NMEA GSV
% =========================================================================
fid = fopen(filename, 'rt');
if fid == -1
    error('No se pudo abrir el archivo %s.', filename);
end
% Variables para almacenar datos
Time_all = [];
SVID_all = [];
Elev_all = [];
CN0_all  = []; % Nueva variable para la relación señal/ruido
current_time = NaN; 
disp('Procesando archivo línea por línea...');
while ~feof(fid)
    line = fgetl(fid);
    
    if length(line) < 10 || line(1) ~= '$'
        continue;
    end
    
    talker = line(2:3);
    type = line(4:6);
    
    % 1. Extraer el tiempo en segundos
    if strcmp(type, 'RMC') || strcmp(type, 'GGA')
        parts = split(line, ',');
        if length(parts) > 1 && ~isempty(parts{2})
            t_str = parts{2};
            if length(t_str) >= 6
                h = str2double(t_str(1:2));
                m = str2double(t_str(3:4));
                s = str2double(t_str(5:6));
                current_time = h*3600 + m*60 + s;
            end
        end
        
    % 2. Extraer satélites, elevación y C/N0
    elseif strcmp(type, 'GSV')
        parts = split(line, {',', '*'});
        num_parts = length(parts);
        
        offset = 0;
        if strcmp(talker, 'GL'), offset = 64; end 
        if strcmp(talker, 'GA'), offset = 100; end 
        if strcmp(talker, 'GB') || strcmp(talker, 'BD'), offset = 200; end 
        
        % Iteramos buscando los bloques de 4 datos de cada satélite
        for j = 5:4:(num_parts - 2)
            if j+3 <= num_parts % Asegurarnos de que el campo C/N0 existe en la trama
                sv_str  = parts{j};
                el_str  = parts{j+1};
                cn0_str = parts{j+3}; % El 4º campo es el C/N0
                
                if ~isempty(sv_str) && ~isempty(el_str)
                    sv = str2double(sv_str);
                    el = str2double(el_str);
                    
                    % Si el satélite no tiene señal aún, el campo viene vacío
                
                    % Si el campo viene vacío, significa pérdida de tracking (bloqueo)
                    if isempty(cn0_str)
                        % Solo lo marcamos como 0 si la elevación es > 0, 
                        % para evitar contar satélites que están por debajo del horizonte terrestre
                        if el > 0
                            cn0 = 0; % C/N0 nulo (Pérdida de enlace)
                        else
                            cn0 = NaN; % Lo ignoramos si está bajo el suelo
                        end
                    else
                        cn0 = str2double(cn0_str);
                    end
                    
                    if ~isnan(sv) && ~isnan(el) && ~isnan(current_time)
                        Time_all(end+1) = current_time;
                        SVID_all(end+1) = sv + offset;
                        Elev_all(end+1) = el;
                        CN0_all(end+1)  = cn0; % Guardamos el dato
                    end
                end
            end
        end
    end
end
fclose(fid);
if isempty(Elev_all)
    disp('No se encontraron elevaciones válidas.');
    return;
end
disp('Generando gráficas...');
satelites_unicos = unique(SVID_all);
% Conversión a Hora UTC
Time_UTC = datetime('today') + seconds(Time_all);
% =========================================================================
% --- CREACIÓN DE LA FIGURA CON SUBPLOTS ---
% =========================================================================
figure('Name', 'Evolución de Elevación y C/N0', 'Color', 'w', 'Position', [100, 100, 1000, 700]);
colores = lines(length(satelites_unicos));
% --- GRÁFICA 1: ELEVACIÓN ---
ax1 = subplot(2, 1, 1);
hold on; grid on;
title('Evolución de la Elevación de los Satélites', 'FontSize', 12);
ylabel('Elevación (Grados)', 'FontSize', 11, 'FontWeight', 'bold');
ylim([0 90]);
% --- GRÁFICA 2: C/N0 ---
ax2 = subplot(2, 1, 2);
hold on; grid on;
title('Evolución de la Calidad de Señal (C/N0)', 'FontSize', 12);
xlabel('Hora (UTC)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('C/N0 (dBHz)', 'FontSize', 11, 'FontWeight', 'bold');
ylim([0 60]);
% Dibujar las líneas de cada satélite en ambas gráficas
for i = 1:length(satelites_unicos)
    satID = satelites_unicos(i);
    idxSat = (SVID_all == satID);
    
    t_sat = Time_UTC(idxSat);
    e_sat = Elev_all(idxSat);
    c_sat = CN0_all(idxSat);
    
    if satID < 64
        label = sprintf('GPS %d', satID);
    elseif satID < 100
        label = sprintf('GLO %d', satID - 64);
    elseif satID < 200
        label = sprintf('GAL %d', satID - 100);
    else
        label = sprintf('BDS %d', satID - 200);
    end
    
    plot(ax1, t_sat, e_sat, '.-', 'Color', colores(i,:), 'DisplayName', label, 'MarkerSize', 8);
    plot(ax2, t_sat, c_sat, '.-', 'Color', colores(i,:), 'HandleVisibility', 'off', 'MarkerSize', 8);
end
hold(ax1, 'off'); hold(ax2, 'off');
xtickformat(ax1, 'HH:mm:ss'); xtickformat(ax2, 'HH:mm:ss');
lgd = legend(ax1, 'show', 'Location', 'eastoutside'); lgd.NumColumns = 2;
linkaxes([ax1, ax2], 'x');

% =========================================================================
% --- ANÁLISIS DEL BLOQUEO FÍSICO (MAPA DE DENSIDAD Y TENDENCIA) ---
% =========================================================================
angulo_bloqueo_teorico = 25; 

figure('Name', 'Validación de Bloqueo Físico (Densidad)', 'Color', 'w', 'Position', [150, 150, 850, 500]);
hold on; grid on;

% Filtramos los datos válidos
idx_validos = ~isnan(CN0_all) & (Elev_all > 0); 
elev_validos = Elev_all(idx_validos);
cn0_validos = CN0_all(idx_validos);

% 1. MAPA DE CALOR (BINSCATTER)
% Sustituye el "manchón" azul por píxeles de colores según la concentración de muestras.
h = binscatter(elev_validos, cn0_validos, [90 60]); % Malla de 90 grados x 60 dBHz
colormap('turbo'); % Paleta de colores térmica (Azul=bajo, Rojo=alto)
cb = colorbar;
cb.Label.String = 'Concentración de muestras (Densidad)';
cb.Label.FontWeight = 'bold';
cb.Label.FontSize = 11;

% 2. LÍNEA DE TENDENCIA (Media Móvil)
% Calcula el valor promedio de la señal para cada grado de elevación
grados_unicos = 0:1:90;
media_cn0 = zeros(size(grados_unicos));
for k = 1:length(grados_unicos)
    % Coge las muestras en un entorno de +/- 1.5 grados para suavizar
    muestras_grado = cn0_validos(abs(elev_validos - grados_unicos(k)) <= 1.5);
    if ~isempty(muestras_grado)
        media_cn0(k) = mean(muestras_grado);
    else
        media_cn0(k) = NaN;
    end
end

% Dibujamos la línea negra gruesa y una línea blanca discontinua encima para que contraste
plot(grados_unicos, media_cn0, 'k-', 'LineWidth', 3.5, 'DisplayName', 'Tendencia Media');
plot(grados_unicos, media_cn0, 'w--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% 3. MÁSCARA DEL BLINDAJE
xline(angulo_bloqueo_teorico, 'r--', 'LineWidth', 2.5, ...
    'Label', sprintf('Corte Físico (%d°)', angulo_bloqueo_teorico), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left', ...
    'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold');

% Sombrear área de vulnerabilidad
ylims = ylim;
patch([0 angulo_bloqueo_teorico angulo_bloqueo_teorico 0], ...
      [0 0 60 60], 'red', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% 4. FORMATO FINAL
title('Mapa de Densidad: Atenuación de Señal según Ángulo de Elevación', 'FontSize', 13);
xlabel('Elevación del Satélite Calculada (Grados)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Calidad de Señal C/N0 (dBHz)', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0 90]);
ylim([0 60]);
ax = gca; ax.FontSize = 11;
hold off;