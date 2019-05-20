%% histone_corr calculates the correlation value between various histone markers and the metabolic flux obtained from the iMAT algorithm
function histone_corr(model, compartment, mode, epsilon, epsilon2, rho, kappa, minfluxflag)
%% INPUTS:
    % model: Initial genome scale model
    % metabolite: The metabolite we're interested in creating a demand
    % reaction. If this argument is left empty, it will take the rxn
    % argument.
    % rxn: The rxn of interest that we are creating a demand reaction through.
    % compartment: specifying the compartment. 
    % mode: for constrain flux regulation
    % epsilon: for constrain flux regulation
    % rho: 
    % kappa:
    % minfluxflag:
%% OUTPUTS:
    % histogram plotting the correlation value (x-axis) corresponding
    % to each histone marker (y-axis) for the demand reaction of
    % interest.
%% histone_corr
load supplementary_software_code celllinenames_ccle1 ccleids_met ccle_expression_metz % contains CCLE cellline names for gene exp, enzymes encoding specific metabolites, and gene expression data (z-transformed)

% New variables
path = './../new_var/';
vars = {...
    [path 'h3_ccle_names.mat'], [path 'h3_marks.mat'],...
    [path 'h3_media.mat'], [path 'h3_relval.mat']...
    }; % contains CCLE cellline names for H3 proteomics, corresponding marker ids, growth media, relative H3 proteomics

for kk = 1:numel(vars)
    load(vars{kk})
end

h3_ccle_names = string(h3_ccle_names);
h3_media = cellstr(h3_media);
h3_media = strrep(h3_media, "McCoy's 5A", "McCoy 5A");

% impute missing values using KNN:
h3_relvals = knnimpute(h3_relval);

% old ones
path = './../vars/';
vars = {[path 'metabolites.mat']};

for kk = 1:numel(vars)
    load(vars{kk})
end

idx = find(ismember(celllinenames_ccle1, h3_ccle_names));
tmp = length(idx);

for i = 1:tmp
    model2 = model;

    % Takes in genes that are differentially expression from Z-score
    % scale
    ongenes = unique(ccleids_met(ccle_expression_metz(:,idx(i)) >= 2));
    offgenes = unique(ccleids_met(ccle_expression_metz(:,idx(i)) <= -2));

    %medium = string(h3_media(i,1));
    % set medium conditions unique to each cell line
    model2 = media(model, h3_media(i));
    disp(i)
    % Get the reactions corresponding to on- and off-genes
    [~,~,onreactions,~] =  deleteModelGenes(model2, ongenes);
    [~,~,offreactions,~] =  deleteModelGenes(model2, offgenes);

    % Get the flux redistribution values associated with different media component addition and deletion
    [fluxstate_gurobi, grate_ccle_exp_dat(i,1),  solverobj_ccle(i,1)] =...
        constrain_flux_regulation(model2, onreactions, offreactions,...
        kappa, rho, epsilon, mode, [], minfluxflag);

    % Add demand reactions from the metabolite list to the metabolic model
    for m = 1:length(metabolites(:,1))
        tmp_met = char(metabolites(m,2));
        tmp = [tmp_met '[' compartment '] -> '];
        tmpname = char(metabolites(m,1));
        model3 = addReaction(model, tmpname, 'reactionFormula', tmp);

        % limit methionine levels for all reactions in the model; it has to be non limiting
        [ix, pos]  = ismember({'EX_met_L(e)'}, model2.rxns);
        model3.lb(pos) = -0.5;
        model3.c(3743) = 0;
        rxnpos = [find(ismember(model3.rxns,tmpname))];
        model3.c(rxnpos) = epsilon2; % we're interested in this reaction

        % get the flux values from iMAT
        [fluxstate_gurobi] =  constrain_flux_regulation(model3,...
            onreactions, offreactions, kappa, rho, epsilon, mode ,[],...
            minfluxflag);
        grate_ccle_exp_dat(i,m+1) = fluxstate_gurobi(rxnpos);
    end
end

% Calculate the pearson correlation coefficients for every demand reaction
[~, col] = size(grate_ccle_exp_dat);
for j = 1:length(col)
    [correl, pval] = corr(grate_ccle_exp_dat(:,j),...
        h3_relvals);  
end
correl = correl';

% Make a heatmap of correlation coefficients versus histone markers for
% several demand reactions
fig = figure;
heatmap(correl)
%set(...
%    gca, 'ytick', [1:length(acet_meth_list_rowlab)], ...
%    'yticklabel', acet_meth_list_rowlab,...
%    'fontsize', 8, ...
%    'fontweight','bold');
%set(gca,'TickDir', 'out');
%set(gca,'box','off');
%set(gca,'linewidth',2);
%set(gcf,'color','white');
%set(gca,'fontsize',12);
%set(gcf, 'Position', [100, 100, 700, 800])
%xlabel('Pearson Correlation');
%ylabel('H3 methylation and acetylation positions');
%xlim([-1,1]);
%title(['Correlation between histone mark expression and ' nam ' metabolic flux'], 'fontweight', 'bold');
%saveas(fig(1), ['./../figures/fig/methylation-' nam '-corr.fig']);
%saveas(fig(1), ['./../figures/tiff/methylation-' nam '-corr.tif']);
end 