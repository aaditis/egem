%% Make Model
% @author: Scott Campit

% metabolic model with nuclear acetylation reaction
load supplementary_software_code acetylation_model 
% CCLE cell line names and gene expression data (z-transformed)
load supplementary_software_code celllinenames_ccle1 ccleids_met ccle_expression_metz 
% cell line names, growth media, total bulk acetylation
load supplementary_software_code acetlevlistmedia acetlevellist acetlevellistval 
% methylation and acetylation levels of different sites from LeRoy et al.,
load methylation_proteomics_validation_data acet_meth_listval acet_meth_list_rowlab 
% list of nutrient conditions and uptake rates
load supplementary_software_code labels media_exchange1 mediareactions1

% Init
initCobraToolbox;
changeCobraSolver('gurobi');

model = acetylation_model;

%% Add transport reactions to nucleus:
    % L-Met
    % Succinate
    % Alpha-ketoglutarate
    % Fumarate
model = addReaction(model, 'METtn',...
    'reactionFormula', 'met-L[c] <=> met-L[n]');
model = addReaction(model, 'SUCCtn',...
    'reactionFormula', 'succ[c] <=> succ[n]');
model = addReaction(model, 'AKGtn',...
    'reactionFormula', 'akg[c] <=> akg[n]');
model = addReaction(model, 'FUMtn',...
    'reactionFormula', 'fum[c] <=> fum[n]');
model = addReaction(model, 'GLYtn',...
    'reactionFormula', 'gly[c] <=> fum[n]');
model = addReaction(model, 'SERtn',...
    'reactionFormula', 'ser__L[c] <=> ser__L[n]');

%% Add demthylation reactions to nucleus (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2732404/)
% Also added aldehyde detox pathway and source of fe

% LSD (Mono and di demethylation only)
model = addReaction(model, 'LSDDMT2n',...
    'reactionFormula', 'Ndmelys[n] + o2[n] + fad[n] -> fadh2[n] + h2o2[n] + mepepimine[n]',...
    'geneRule', 'LSD1 or LSD2');
model = addReaction(model, 'PEPHYDROX2n',...
    'reactionFormula', 'mepepimine[n] + h2o[n] -> Nmelys[n] + fald[n]',...
    'geneRule', 'LSD1 or LSD2');
model = addReaction(model, 'LSDDMT1n',...
    'reactionFormula', 'Nmelys[n]+ o2[n] + fad[n] -> fadh2[n] + h2o2[n] + pepimine[n]',...
    'geneRule', 'LSD1 or LSD2');
model = addReaction(model, 'PEPHYDROX1n',...
    'reactionFormula', 'pepimine[n] + h2o[n] -> peplys[n] + fald[n]',...
    'geneRule', 'LSD1 or LSD2');

% Dioxygenase (Mono, di, and tridemethylation)
model = addReaction(model, 'JMJDMT3n',...
    'reactionFormula', 'Ntmelys[n] + akg[n] + o2[n] + fe2[n] -> Ndmelys[n] + fald[n] + co2[n] + fe3[n] + succ[n]',...
    'geneRule', 'JARID1A or JARID1B or JARID1C or JARID1D or JMJD3 or JHDM3');
model = addReaction(model, 'JMJDMT2n',...
    'reactionFormula', 'Ndmelys[n] + akg[n] + o2[n] + fe2[n] -> Nmelys[n] + fald[n] + co2[n] + fe3[n] + succ[n]',...
    'geneRule', 'JARID1A or JARD1B or JARID1C or JARID1D or JHDM2 or JHDM3 or PHF8 or JMJD3 or JHDM1');
model = addReaction(model, 'JMJDMT1n',...
    'reactionFormula', 'Nmelys[n] + akg[n] + o2[n] + fe2[n] -> peplys[n] + fald[n] + co2[n] + fe3[n] + succ[n]',...
    'geneRule', 'NO66 or JARID1B or JHDM2 or PHF8 or JHDM1');

% Aldehyde detoxification by ALDH to formate (GeneCards
model = addReaction(model, 'ALDHn',...
    'reactionFormula', 'fald[n] + nad[n]+ h2o[n] -> for[n] +nadh[n] + h[n]',...
    'geneRule', 'ALDH1A1 or ALDH3A1 or ALDH1B1 or AKR1A1 or ALDH1A3 or ADH1B or ALDH7A1');

% Iron reactions {Not sure how they are introduced so I created sink and demand reactions}
% https://www.cell.com/trends/biochemical-sciences/pdf/S0968-0004(15)00237-6.pdf
model = addReaction(model, 'Fe2_sink',...
    'reactionFormula', 'fe2[n] <=> ');
model = addReaction(model, 'Fe3_sink',...
    'reactionFormula', 'fe3[n] <=> ');
model = addReaction(model, 'Fe2_demand',...
    'reactionFormula', 'fe2[n] -> ');
model = addReaction(model, 'Fe3_demand',...
    'reactionFormula', 'fe3[n] -> ');
%model = addReaction(model, 'FE2tn', 'reactionFormula', 'fe2[c] -> fe3[n]');

%% FAD Pool (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4893201/)
% Since it is not known how flavin is introduced in the nucleus, I
% created a sink reaction and consumption of fad to fmn and amp.
    % RFK is only in cytoplasm (uniprot) -> no de novo synthesis in nucleus
model = addReaction(model, 'FADn',...
    'reactionFormula', 'fad[n] <=> '); 
model = addReaction(model, 'FADDPn',...
    'reactionFormula', 'fad[n] + h2o[n]  -> amp[n] + fmn[n] + 2 h[n]',...
    'geneRule', 'TKFC');
model = addReaction(model, 'FLAD1n',...
    'reactionFormula', 'fmn[n] + atp[n]  -> ppi[n] + fad[n]',...
    'geneRule', 'FLAD1');

%% Nuclear folate metabolism 
    %(http://arjournals.annualreviews.org/doi/full/10.1146/annurev-nutr-071714-034441?url_ver=Z39.88-2003&rfr_id=ori:rid:crossref.org&rfr_dat=cr_pub%3dpubmed)
    % https://academic.oup.com/advances/article/2/4/325/4591505
    % Sink reaction for folate: not known how folate is imported into
    % nucleus
    % Formate already has a transport reaction {FORtrn}
    % MTHFD1: Formate + THF + ATP + NADPH <=> 5,10meTHF + NADP+ + ADP + Pi
    % SHMT1, SHMT2a: THF + Ser <=> 5, 10meTHF + Gly
    % TYMS: THF+ dUMP -> DHF + dTMP
    % TK1 dT -> dTMP
        % Do I have to modify biomass reaction?
    % DHFR: THF + NADP+ <=> DHF + NADPH
model = addReaction(model, 'Folate_sink',...
    'reactionFormula', 'fol[n] <=> '); 
model = addReaction(model, 'MTHFD1n',...
    'reactionFormula', 'for[n] + thf[n] + atp[n] + nadph[n] <=> mlthf[n] + nadp[n] + adp[n] + pi[n]',...
    'geneRule', 'MTHFD1');
model = addReaction(model, 'TYMS',...
    'reactionFormula', 'mlthf[n] + dump[n] <=> dhf[n] + dtmp[n]',...
    'geneRule', 'TYMS');
model = addReaction(model, 'TMDK1n',...
    'reactionFormula', 'thymd[n] -> dtmp[n]',...
    'geneRule', 'TMDK1');
model = addReaction(model, 'DHFRn',...
    'reactionFormula', 'dhf[n] + nadph[n] -> thf[n] + nadp[n]',...
    'geneRule', 'DHFR');
model = addReaction(model, 'SHMTn',...
    'reactionFormula', 'thf[n] + ser[n] <=> gly[n] + mltf[n]',...
    'geneRule', 'SHMT1 or SHMT2');


