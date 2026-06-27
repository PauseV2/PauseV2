Jobs = {
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        grades = {
            [0] = { name = 'Freelancer', payment = 10 },
        },
    },
    police = {
        label = 'Los Santos Police Department',
        defaultDuty = false,
        grades = {
            [0] = { name = 'Cadet', payment = 50 },
            [1] = { name = 'Officer', payment = 75 },
            [2] = { name = 'Sergeant', payment = 100 },
            [3] = { name = 'Chief', payment = 150, isboss = true },
        },
    },
    ambulance = {
        label = 'Emergency Medical Services',
        defaultDuty = false,
        grades = {
            [0] = { name = 'Trainee', payment = 50 },
            [1] = { name = 'Paramedic', payment = 75 },
            [2] = { name = 'Chief Medic', payment = 120, isboss = true },
        },
    },
}
