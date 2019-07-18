%% Run analyses for epigenome-scale metabolic models
initCobraToolbox;
changeCobraSolver('gurobi');
%% Load genome-scale metabolic models. Must run from `/matlab/scripts` directory

% The bulk eGEM model
load ./../models/eGEM.mat 
model = eGEM;

% New acetylation model containing ACSS2 and PDH in nucleus
%load ./../models/acetyl2.mat

% Minial eGEM that does not contain one carbon reactions and demethylation
% rxns
%load ./../models/min.mat % minimal eGEM model
%model = eGEM_min;

% Human metabolic reconstruction 1 (RECON1; Duarte et al., 2007)
%load ./../models/recon1
%model = metabolicmodel;

% Acetylation model from Shen et al., 2019
%load ./../shen-et-al/supplementary_software_code acetylation_model
%model = acetylation_model; 

%% Metabolic sensitivity analysis for excess and depleted medium components
    % INPUT:
        % switch case arguments:
            % single-reaction-analysis - optimizes the flux of a single
            % reaction
            % dyn - optimizes the flux of several reactions using the results
            % from `single-reaction-analysis`
            % grate - fix biomass to max value and optimize for histone
            % markers
    % OUTPUT: 
        % Heatmaps of the metabolic fluxes, shadow prices, and reduced
        % costs corresponding to each reaction / medium component pair.

% All reactions
load('./../vars/metabolites.mat')
        
% Optimization 1A: Run Single reaction activity (SRA)
%medium_of_interest = {'RPMI', 'DMEM', 'L15'};
[~, medium] = xlsfinfo('./../../data/uptake.xlsx');
medium_of_interest = medium;
epsilon2 = [1E-6, 1E-5, 1E-4, 1E-3, 1E-2, 0.1, 1];
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    for n = 1:length(epsilon2)
        % Run all
        str =  strcat("[sra", string(n), '_', medium_of_interest(med),...
            "] = metabolic_sensitivity(model, metabolites, 'n',", ...
            "epsilon2(n), 'zscore', 'sra', medium_of_interest(med), []);");
        eval(str);
        % Plot all
        str = strcat("plot_heatmap(sra", string(n), '_',...
            medium_of_interest(med), ", metabolites, 'sra', epsilon2(n), medium_of_interest(med))");
        eval(str);
    end
end

% Calculate epsilon2 values to use for fba by dynamic range
for i=1:length(medium)
    str = strcat("epsilon2_",lower(medium_of_interest(medium)), " = ", ...
        "dynamic_range(sra1_", medium_of_interest(medium), ", ", ...
        "sra2_", medium_of_interest(medium), ", ", ...
        "sra3_", medium_of_interest(medium), ", ", ...
        "sra4_", medium_of_interest(medium), ", ", ...
        "sra5_", medium_of_interest(medium), ", ", ...
        "sra6_", medium_of_interest(medium), ", ", ...
        "sra7_", medium_of_interest(medium), ", ", ...
        "dynamic");
    eval(str);
end

% Optimization procedures using FBA and FVA
for med = 1:length(medium_of_interest)
    % Run all reactions using FBA w/o competition for all reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"_noCompetition]", ...
        "= metabolic_sensitivity(model, metabolites, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'no_competition',", ...
        "medium_of_interest(med), []);");
    eval(str);
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)),...
        "_noComp, metabolites, 'no_competition', epsilon2, medium_of_interest(med))");
    eval(str);

    % Run all reactions using FBA w/ competition for all reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"_competition, ", ...
        "] = metabolic_sensitivity(model, metabolites, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'competition',", ...
        "medium_of_interest(med), []);"); 
    eval(str);
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)), ...
        "_comp, metabolites, 'competition', epsilon2, medium_of_interest(med))");
    eval(str);

    % Run FVA for all reactions
    str =  strcat("[fva_", lower(medium_of_interest(med)),...
        "] = metabolic_sensitivity(model, metabolites, 'n', epsilon2_",...
        lower(medium_of_interest(med)), ", 'zscore', 'fva', medium_of_interest(med), 90);");
    eval(str);
    str = strcat("plot_heatmap(fva_", lower(medium_of_interest(med)),...
        ", metabolites, 'fva', epsilon2, medium_of_interest(med))");
    eval(str);
end

% Save results for all reactions
[fba_nocomp_rpmi_excess, fba_nocomp_rpmi_depletion] = metabolite_dict(fba_rpmi_noComp, metabolites, 'RPMI', 'T2| All Rxns FBA', 'no_competition');
[fba_nocomp_dmem_excess, fba_nocomp_dmem_depletion] = metabolite_dict(fba_dmem_noComp, metabolites, 'DMEM', 'T2| All Rxns FBA', 'no_competition');
[fba_nocomp_l15_excess, fba_nocomp_l15_depletion] = metabolite_dict(fba_l15_noComp, metabolites, 'L15', 'T2| All Rxns FBA', 'no_competition');
[fba_comp_rpmi_excess, fba_comp_rpmi_depletion] = metabolite_dict(fba_rpmi_comp, metabolites, 'RPMI', 'T2| All Rxns FBA', 'competition');
[fba_comp_dmem_excess, fba_comp_dmem_depletion] = metabolite_dict(fba_dmem_comp, metabolites, 'DMEM', 'T2| All Rxns FBA', 'competition');
[fba_comp_l15_excess, fba_comp_l15_depletion] = metabolite_dict(fba_l15_comp,  metabolites,'L15', 'T2| All Rxns FBA', 'competition');
[fva_rpmi_excess, fva_rpmi_depletion] = metabolite_dict(fva_rpmi,  metabolites, 'RPMI', 'T3| All Rxns FVA', 'fva');
[fva_dmem_excess, fva_dmem_depletion] = metabolite_dict(fva_dmem,  metabolites, 'DMEM', 'T3| All Rxns FVA', 'fva');
[fva_l15_excess, fva_l15_depletion] = metabolite_dict(fva_l15,  metabolites, 'L15', 'T3| All Rxns FVA', 'fva');

% Histone reactions only
histone_rxns_only = metabolites(2:5, :);

% Optimization 1B: Run Single reaction activity (SRA) for histone reactions
% only
epsilon2 = [1E-6, 1E-5, 1E-4, 1E-3, 1E-2, 0.1, 1];
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    for n = 1:length(epsilon2)
        % Run all
        str =  strcat("[sra_hist_", string(n), '_', medium_of_interest(med),...
            "] = metabolic_sensitivity(model, histone_rxns_only, 'n',", ...
            "epsilon2(n), 'zscore', 'sra', medium_of_interest(med), []);");
        eval(str)
        % Plot all
        str = strcat("plot_heatmap(sra", string(n), '_',...
            medium_of_interest(med), ", histone_rxns_only, 'sra', epsilon2(n), medium_of_interest(med))");
        eval(str)
    end
end

for i=1:length(medium)
    str = strcat("epsilon2_histOnly_",lower(medium_of_interest(medium)), " = ", ...
        "dynamic_range(sra1_hist_", medium_of_interest(medium), ", ", ...
        "sra2_hist_", medium_of_interest(medium), ", ", ...
        "sra3_hist_", medium_of_interest(medium), ", ", ...
        "sra4_hist_", medium_of_interest(medium), ", ", ...
        "sra5_hist_", medium_of_interest(medium), ", ", ...
        "sra6_hist_", medium_of_interest(medium), ", ", ...
        "sra7_hist_", medium_of_interest(medium), ", ", ...
        "dynamic");
    eval(str);
end

% Calculate epsilon2 values to use for fba by dynamic range
epsilon2_dmem = dynamic_range(sra1_DMEM, sra2_DMEM, sra3_DMEM, sra4_DMEM,...
    sra5_DMEM, sra6_DMEM, sra7_DMEM, "dynamic");
epsilon2_rpmi = dynamic_range(sra1_RPMI, sra2_RPMI, sra3_RPMI, sra4_RPMI,...
    sra5_RPMI, sra6_RPMI, sra7_RPMI, "dynamic");
epsilon2_l15 = dynamic_range(sra1_L15, sra2_L15, sra3_L15, sra4_L15,...
    sra5_L15, sra6_L15, sra7_L15, "dynamic");

% Optimization 2B: Run Flux balance analysis (FBA) w/ and w/o competition
medium_of_interest = {'RPMI', 'DMEM', 'L15'};
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    
    % Run all without competition for histone reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"_noComp]", ...
        "= metabolic_sensitivity(model, histone_rxns_only, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'no_competition',", ...
        "medium_of_interest(med), []);");
    eval(str)
    
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)),...
        "_noComp, histone_rxns_only, 'no_competition', 'noComp', medium_of_interest(med))");
    eval(str)
end

medium_of_interest = {'RPMI', 'DMEM', 'L15'};
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    % Run all w/ competition for histone reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"_comp", ...
        "] = metabolic_sensitivity(model, histone_rxns_only, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'competition',", ...
        "medium_of_interest(med), []);"); 
    eval(str)
    
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)), ...
        "_comp, histone_rxns_only, 'competition', 'comp', medium_of_interest(med))");
    eval(str)
end

% Optimization 3C: Run Flux variability analysis (FVA) for histone
% reactions
medium_of_interest = {'RPMI', 'DMEM', 'L15'};
for med=1:length(medium_of_interest)
    str =  strcat("[fva_", lower(medium_of_interest(med)),...
        "] = metabolic_sensitivity(model, histone_rxns_only, 'n', epsilon2_",...
        lower(medium_of_interest(med)), ", 'zscore', 'fva', medium_of_interest(med), 100);");
    eval(str)
    
    % Plot
    str = strcat("plot_heatmap(fva_", lower(medium_of_interest(med)),...
        ", histone_rxns_only, 'fva', 'fva_hist', medium_of_interest(med))");
    eval(str)
end

% Save results for histone reactions only
[fba_nocomp_rpmi_excess, fba_nocomp_rpmi_depletion] = metabolite_dict(fba_rpmi_noComp, histone_rxns_only, 'RPMI', 'T2| All Rxns FBA', 'no_competition');
[fba_nocomp_dmem_excess, fba_nocomp_dmem_depletion] = metabolite_dict(fba_dmem_noComp, histone_rxns_only, 'DMEM', 'T2| All Rxns FBA', 'no_competition');
[fba_nocomp_l15_excess, fba_nocomp_l15_depletion] = metabolite_dict(fba_l15_noComp, histone_rxns_only, 'L15', 'T2| All Rxns FBA', 'no_competition');
[fba_comp_rpmi_excess, fba_comp_rpmi_depletion] = metabolite_dict(fba_rpmi_comp, histone_rxns_only, 'RPMI', 'T2| All Rxns FBA', 'competition');
[fba_comp_dmem_excess, fba_comp_dmem_depletion] = metabolite_dict(fba_dmem_comp, histone_rxns_only, 'DMEM', 'T2| All Rxns FBA', 'competition');
[fba_comp_l15_excess, fba_comp_l15_depletion] = metabolite_dict(fba_l15_comp, histone_rxns_only, 'L15', 'T2| All Rxns FBA', 'competition');
[fva_rpmi_excess, fva_rpmi_depletion] = metabolite_dict(fva_rpmi, histone_rxns_only, 'RPMI', 'T3| All Rxns FVA', 'fva');
[fva_dmem_excess, fva_dmem_depletion] = metabolite_dict(fva_dmem, histone_rxns_only, 'DMEM', 'T3| All Rxns FVA', 'fva');
[fva_l15_excess, fva_l15_depletion] = metabolite_dict(fva_l15, histone_rxns_only, 'L15', 'T3| All Rxns FVA', 'fva');

%% Correlation values between histone markers and metabolic flux
% INPUTS:
    % h3marks: list of H3 marks from CCLE data (column values)
    % h3names: list of CCLE cell lines (row values)
    % h3vals: matrix containing values corresponding to h3marks and h3names

% Initialize params for iMAT algorithm
compartment = 'n';
mode = 1;
epsilon = 1E-3;
rho = 1;
kappa = 1E-3;
minfluxflag = 0;

% Run histone_corr using the H3 z-score normalized proteomics dataset and
% running flux balance analysis. Optimize using single reaction analysis
epsilon2 = {epsilon2_dmem, epsilon2_rpmi, epsilon2_l15};
for eps = 1:length(epsilon2)
    new_eps = epsilon2(eps);
    str = strcat("[CCLE] = histone_corr(model, metabolites, new_eps,", ...
        "1, 1E-3, 1, 1E-3, 0, 'non-competitive_cfr', 'CCLE', [])");
    eval(str)
end
    
% Load the LeRoy et al., proteomics dataset

%% Transform figures
path = './../figures/new-model/';
new_ext = '.tif';
old_ext = '.fig';
transform_fig(path, old_ext, new_ext)


%% Density plot
% A = densityplot('eGEMn');
% 
% [x,y,z] = meshgrid(1:50, 1:20, 1:6);
% for i=1:6
%     surf(x(:,1,1), y(1,:,1), A(:,:,i));
%     hold on;
%     colorbar
% end