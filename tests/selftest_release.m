function selftest_release()
% Regression checks for model input and asymmetric restraints.
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
selftest_ZhaoAppendixB;
p = struct('width',60,'height',15,'nx',8,'ny',2,'P',1, ...
    'Emod',[29007.5 0;0 4351.1],'x0',[.01 .01], ...
    'maxIter',400,'doPlot',false);
S = Engine(p);
assert(S.converged && S.equilOK);
assert(abs(S.J-.0108334922982584)<1e-10);
assert(isfield(S,'Fe') && ~isfield(S,'Naxial'));
assert(abs(Results.loadPath(S.Fe,S.L)/(S.P*S.height)-S.Z)<1e-12);
checkSavedForces(S);
assert(S.symmetricLR,'Default pin/roller model must retain symmetry.');
assert(isequaln(Results.metrics(S),Results.metrics(S,S.plotShowFrac,S.plotMergeCollinear)));
S.plotMergeCollinear = false;
M = Results.metrics(S);
assert(M.nMerged==M.nShown,'Metrics must respect the stored merge setting.');
q = p; q.tieFract = .5;
mustFail(@() Engine(q),'Engine:unknownParameter');
q = rmfield(p,'maxIter');
mustFail(@() Engine(q),'Engine:missingParameter');
q = p; q.volGroups = [1 3];
mustFail(@() Engine(q),'Engine:invalidGroups');
mustFail(@() Results.rescale({},'gamma'),'Results:optionPairs');
% Vertical restraints and loading mirror, horizontal restraints do not.
q = p; q.maxIter = 6;
q.supports = [0 0 1 1;60 0 0 1;15 0 1 0];
S = Engine(q);
assert(~S.symmetricLR,'Asymmetric horizontal restraints must disable averaging.');
fprintf('Release regression checks PASSED.\n');
end

function checkSavedForces(S)
% Test both new-format persistence and migration of existing result files.
folder = tempname;
mkdir(folder);
guard = onCleanup(@() removeFixture(folder));
Results.save(S,[],folder);
loaded = Results.load(folder);
assert(isequal(loaded.Fe,S.Fe) && ~isfield(loaded,'Naxial'));
S.Naxial = S.Fe; S = rmfield(S,'Fe');
save(fullfile(folder,'result.mat'),'S');
loaded = Results.load(folder);
assert(isequal(loaded.Fe,S.Naxial) && ~isfield(loaded,'Naxial'));
% Single-material display must classify members by the renamed signed forces.
loaded.X = sum(loaded.X,2);
loaded.plotShowFrac = 0;
M = Results.metrics(loaded,0,false);
assert(isequal(M.mat,1+(loaded.Fe(loaded.X>0)<0)));
clear guard
end

function removeFixture(folder)
delete(fullfile(folder,'result.mat'));
delete(fullfile(folder,'summary.txt'));
rmdir(folder);
end

function mustFail(f,id)
try
    f();
catch ME
    assert(strcmp(ME.identifier,id),'Unexpected error: %s',ME.identifier);
    return
end
error('selftest:missingError','Expected error %s.',id);
end
