%% TFG - SIMULACIÓN FÍSICA: CILINDRO REAL (VERSIÓN COMPATIBLE)
% Simulación de onda completa (MoM) de la antena cerámica optimizada
% dentro de una cavidad cilíndrica metálica real.

clc; clear; close all;

fprintf('=== SIMULACIÓN FÍSICA: ANTENA DENTRO DE CILINDRO ===\n');

%% 1. DEFINICIÓN DE LA ANTENA CERÁMICA
f_GPS = 1.57542e9; 
epsilon_r = 20;
h_subs = 0.004;

% Parámetros dimensionales optimizados
L_base = 3e8 / (2 * 1.57542e9 * sqrt(20)); 
scaling_factor = 1.37 / 1.575; 
L_final = L_base * scaling_factor;
Feed_final = L_final / 3.5; 

% Construcción del parche
ceramica = dielectric('Name', 'Ceramica_GPS', 'EpsilonR', epsilon_r, ...
                      'LossTangent', 0.002, 'Thickness', h_subs);

patch = patchMicrostrip('Substrate', ceramica, ...
                        'GroundPlaneLength', 0.070, ...
                        'GroundPlaneWidth', 0.070, ...
                        'Length', L_final, ...
                        'Width', L_final, ...
                        'Height', h_subs, ...
                        'FeedOffset', [Feed_final, Feed_final]);

% MALLADO MANUAL (IMPORTANTE): Evita cuelgues de memoria
mesh(patch, 'MaxEdgeLength', 0.0045); 

fprintf('1. Antena cerámica generada y mallada.\n');

%% 2. CONSTRUCCIÓN DE LA PROTECCIÓN
% Dimensiones se consideren oportunas
R_cilindro = 0.186; 
H_cilindro = 0.086; 
%de estos datos depende la máscara


fprintf('2. Construyendo protección física (R=%.1f cm, H=%.1f cm)...\n',R_cilindro*100, H_cilindro*100);

% Usamos cavityCircular (objeto nativo para cilindros)
protection = cavityCircular;
protection.Exciter = patch;       
protection.Radius = R_cilindro;
protection.Height = H_cilindro;
protection.Spacing = h_subs;      % Antena apoyada en el fondo

%% 3. VISUALIZACIÓN DE LA GEOMETRÍA
figure('Color', 'w', 'Name', 'Configuración Física');
show(protection);
title('Modelo Físico: Antena Cerámica en Cavidad');
view(30, 20); 

%% 4. CÁLCULO DEL DIAGRAMA DE RADIACIÓN
fprintf('3. Calculando diagrama de radiación (MoM)...\n');
fprintf('   (Calculando corrientes en las paredes metálicas...)\n');

figure('Color', 'w', 'Name', 'Diagrama Final Protegido');

% pequeña corrección que he estimado: Eliminamos 'Resolution', 2. Usamos la función estándar.
patternElevation(protection, f_GPS, 0);

title({'Diagrama de Radiación REAL (Simulación Física)', ...
       ['Cilindro Metálico: R=' num2str(R_cilindro*100) 'cm, H=' num2str(H_cilindro*100) 'cm']});

% --- LÍNEAS DE REFERENCIA DE BLOQUEO ---
angle_rad = atan(H_cilindro / R_cilindro);
mask_deg_cenit = 90 - rad2deg(angle_rad); % Ángulo desde el cenit

hold on;
th_m = deg2rad(mask_deg_cenit);
polarplot([th_m th_m], [-40 20], 'r--', 'LineWidth', 2);
polarplot([-th_m -th_m], [-40 20], 'r--', 'LineWidth', 2);

% Texto explicativo
text(deg2rad(0), 10, 'CONO VISIBLE', 'Color', 'g', 'BackgroundColor', 'w', 'HorizontalAlignment', 'center', 'FontSize', 8);
text(deg2rad(60), -20, 'BLOQUEADO', 'Color', 'r', 'HorizontalAlignment', 'center', 'FontSize', 8);

fprintf('¡Simulación Completada! Mira la figura generada.\n');