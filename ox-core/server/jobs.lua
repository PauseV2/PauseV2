OxJobs = {}

function OxJobs.GetGrade(jobName, grade)
    local job = Jobs[jobName]
    return job and job.grades[grade] or nil
end

OxCallbacks.Register('ox:setDuty', function(source, onduty)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end

    player:SetDuty(onduty)
    return true, player.job
end)

-- Pays every on-duty, employed character their grade's wage on an interval.
CreateThread(function()
    while true do
        Wait(30 * 60 * 1000)

        for _, player in pairs(Ox.Players) do
            if player.job and player.job.onduty and player.job.name ~= 'unemployed' then
                local gradeData = OxJobs.GetGrade(player.job.name, player.job.grade)

                if gradeData and gradeData.payment then
                    player:AddMoney('bank', gradeData.payment, 'paycheck')
                end
            end
        end
    end
end)
