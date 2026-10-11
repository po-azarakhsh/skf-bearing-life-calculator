function SKF_Life_Standalone
% Windows executable entry point. Keep the application alive until closed.
testOutput = getenv('SKF_STANDALONE_SMOKE_OUTPUT');
if ~isempty(testOutput)
    fig = SKF_Life_App("off");
    cleanup = onCleanup(@()delete(fig));
    drawnow;
    R = fig.UserData.get_result();
    assert(abs(R.dm-100)<1e-10 && abs(R.aSKF-3.05056544122)<1e-8, ...
        'SKF:SmokeTestFailed','Standalone calculation differs from the reference.');
    fid = fopen(testOutput,'w');
    assert(fid>=0,'Cannot write smoke test output.');
    fileCleanup = onCleanup(@()fclose(fid));
    fprintf(fid,'%s',jsonencode(R,'PrettyPrint',true));
    return
end
fig = SKF_Life_App;
waitfor(fig);
end
