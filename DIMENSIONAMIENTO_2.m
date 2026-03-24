%% TFG - OPTIMIZACIÓN DE CAVIDAD (BARRIDO PARAMÉTRICO)
clc; clear; close all;

%% 1. CONFIGURACIÓN DEL ESCENARIO
f_GPS = 1.57542e9; 
% --- VARIABLES DE DISEÑO ---
% Radios: De 4cm a 30cm con los saltos que se reguieran si preferimos
% precisión o velocidad
radios_test = linspace(0.04, 0.30,5); % se Aumenta resolución para suavidad y prrecisón y bajamos  par avelocidad
% Alturas: De 2cm a 30cm se pueden cambiar si huiciese falta
alturas_test = linspace(0.02, 0.30, 5);
% Matrices para guardar resultados
Matriz_Ratio = zeros(length(radios_test), length(alturas_test));

fprintf('=== INICIANDO BARRIDO DE OPTIMIZACIÓN (%d iteraciones) ===\n', ...
        length(radios_test)*length(alturas_test));

%% 2. BUCLE DE SIMULACIÓN
t_inicio = tic;
counter = 0;

% NOTA: Para pruebas rápidas usa pocas iteraciones. Para la final, aumenta linspace.
for i = 1:length(radios_test)
    for j = 1:length(alturas_test)
        counter = counter + 1;
        R = radios_test(i);
        H = alturas_test(j);
        
        fprintf('Simulando %d/%d: R=%.1f cm, H=%.1f cm... ', ...
                counter, numel(Matriz_Ratio), R*100, H*100);
        
        % --- A. CONSTRUIR ANTENA BASE ---
        ceramica = dielectric('Name', 'Ceramica_GPS', 'EpsilonR', 20, ...
                              'LossTangent', 0.002, 'Thickness', 0.004); 
        patch = patchMicrostrip('Substrate', ceramica, 'Height', 0.004, ...
                                 'GroundPlaneLength', 0.050, 'GroundPlaneWidth', 0.050);
        
        % Sintonización
        f_semilla = 1.539985e9;
        patch = design(patch, f_semilla); 
        factor_visual = 1.0020; 
        patch.Length = patch.Length * factor_visual;
        patch.Width = patch.Width * factor_visual;
        patch.FeedOffset = patch.FeedOffset * factor_visual;
        
        % --- B. CONSTRUIR EL CILINDRO ---
        cavidad = cavityCircular;   
        cavidad.Exciter = patch;
        cavidad.Radius = R;
        cavidad.Height = H;         
        cavidad.Spacing = 0.004;    
        
        % --- C. SIMULAR ---
        try
            % Ganancia Cenit (90º) vs Amenaza (5º sobre horizonte)
            G_zenith = pattern(cavidad, f_GPS, 0, 90); 
            G_threat = pattern(cavidad, f_GPS, 0, 10); % Modificado para ataque 

            % Umbral de seguridad: No permitimos que el jammer entre con más de -10 dBi
umbral_seguridad_jammer = -10; 

if G_zenith < 0 || G_threat > umbral_seguridad_jammer
    % Si perdemos el satélite O el jammer entra demasiado fuerte: CASTIGO
    Matriz_Ratio(i,j) = -20; 
else
    % Si es un diseño seguro, calculamos su nota (Ratio)
    Matriz_Ratio(i,j) = G_zenith - G_threat;
end
            fprintf('Ratio: %.2f dB\n', Matriz_Ratio(i,j));
            
        catch
            fprintf('ERROR (Geometría inválida)\n');
            Matriz_Ratio(i,j) = -50; 
        end
    end
end
toc(t_inicio);

%% 3. VISUALIZACIÓN (MAPA DE CALOR)
figure('Color', 'w', 'Name', 'Mapa de Protección');
% Usamos imagesc o surf. Surf es mejor para 3D.
surf(alturas_test*100, radios_test*100, Matriz_Ratio);
view(0, 90); shading interp; 
cb = colorbar;
cb.Label.String = 'Ratio de Protección (dB)';
xlabel('Altura Cilindro (cm)'); ylabel('Radio Cilindro (cm)');
title('Optimización Geométrica: Ratio Cenit/Amenaza');

% Marcar el máximo encontrado
[max_val, idx] = max(Matriz_Ratio(:));
[r_opt, h_opt] = ind2sub(size(Matriz_Ratio), idx);
hold on; 
p_max = plot3(alturas_test(h_opt)*100, radios_test(r_opt)*100, max_val+10, ...
      'rp', 'MarkerFaceColor','w', 'MarkerSize', 10);