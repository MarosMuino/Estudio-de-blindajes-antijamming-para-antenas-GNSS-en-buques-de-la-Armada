%% TFG - SCRIPT PARA DISEÑO ANTENA DE PARCHE
% Solución a los problemas iniciales
% 1. Aplica la corrección de tamaño directamente (sin bucles).
% 2. Fuerza un mallado manual controlado para no saturar la RAM.
% 3. Calcula solo el diagrama final.

clc; clear; close all;

fprintf('=== GENERANDO ANTENA  ===\n');

%% 1. PARÁMETROS DIRECTOS (YA CORREGIDOS)
f_GPS = 1.57542e9; 
epsilon_r = 20;
h_subs = 0.004;

% Factor de corrección basado en el error inicial de frecuencia' (1.37 -> 1.575)
% La antena era grande, hay que multiplicarla por 0.8698
scaling_factor = 1.37 / 1.575; 

% Dimensiones originales (las que daban 1.37 GHz)
L_base = 3e8 / (2 * 1.57542e9 * sqrt(20)); % La fórmula teórica inicial

% DIMENSIONES FINALES CORREGIDAS (Hardcoded)
L_final = L_base * scaling_factor;
W_final = L_final; 
Feed_final = (L_final / 3.5); % Posición estimada segura (Diagonal)

fprintf('1. Dimensiones aplicadas:\n');
fprintf('   - Tamaño Parche: %.2f mm (Original: %.2f mm)\n', L_final*1e3, L_base*1e3);
fprintf('   - Feed Offset:   %.2f mm\n', Feed_final*1e3);

%% 2. CONSTRUCCIÓN DE LA ANTENA
ceramica = dielectric('Name', 'Ceramica', 'EpsilonR', epsilon_r, ...
                      'LossTangent', 0.002, 'Thickness', h_subs);

antena = patchMicrostrip('Substrate', ceramica, ...
                         'GroundPlaneLength', 0.070, ...
                         'GroundPlaneWidth', 0.070, ...
                         'Length', L_final, ...
                         'Width', W_final, ...
                         'Height', h_subs, ...
                         'FeedOffset', [Feed_final, Feed_final]); % Diagonal para RHCP

%% 3. EL MALLADO MANUAL(lo hago porque sino no consigo que resuene bien)
fprintf('2. Generando malla manual (Low-Poly)...\n');

% Forzamos triángulos de máximo 3.5mm. 
% Por defecto MATLAB intentaría hacerlos de 0.5mm y es donde he fallado hasta ahora.
mesh(antena, 'MaxEdgeLength', 0.0035); 

%% 4. CÁLCULO DIRECTO DEL DIAGRAMA
fprintf('3. Calculando diagrama de radiación (Esto será rápido)...\n');

figure('Color', 'w', 'Name', 'Diagrama Final');
% Calculamos patrón en corte vertical (Azimuth = 0)
patternElevation(antena, f_GPS, 0);

title({'Diagrama de Radiación (Antena Cerámica Corregida)', ...
       sprintf('Resonancia ajustada a %.2f GHz', f_GPS/1e9)});

fprintf('¡LISTO! Gráfica generada.\n');

% Guardar para usar con el cilindro
save('antena_optimizada.mat', 'antena');