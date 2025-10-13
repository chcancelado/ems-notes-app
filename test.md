```mermaid
flowchart LR
    subgraph Flutter App
        Main[Main.dart\nApp Bootstrap]
        LoginPage[LoginPage\n(login_page.dart)]
        PatientInfoPage[PatientInfoPage\n(patient_info_page.dart)]
        VitalsPage[VitalsPage\n(vitals_page.dart)]
        ReportPage[ReportPage\n(report_page.dart)]

        LoginCtrl[LoginController]
        PatientInfoCtrl[PatientInfoController]
        VitalsCtrl[VitalsController]
        ReportCtrl[ReportController]
    end

    subgraph Supabase Backend
        PatientInfoTbl[(patient_info table)]
        VitalsTbl[(vitals table)]
        ReportsTbl[(reports table)]
        AuthUsers[(auth.users)]
    end

    Main -->|init/route| LoginPage
    Main -->|init/route| PatientInfoPage
    Main -->|init/route| VitalsPage
    Main -->|init/route| ReportPage

    LoginPage --> LoginCtrl
    PatientInfoPage --> PatientInfoCtrl
    VitalsPage --> VitalsCtrl
    ReportPage --> ReportCtrl

    LoginCtrl -->|sign in/out| AuthUsers
    PatientInfoCtrl -->|upsert & fetch| PatientInfoTbl
    VitalsCtrl -->|insert & select| VitalsTbl
    ReportCtrl -->|load notes| ReportsTbl
    ReportCtrl -->|uses| PatientInfoCtrl
    ReportCtrl -->|uses| VitalsCtrl

    AuthUsers -->|RLS user_id| PatientInfoTbl
    AuthUsers -->|RLS user_id| VitalsTbl
```