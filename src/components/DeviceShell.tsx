import React from "react";

const NAV_ITEMS = [
  { key: "search", label: "Search" },
  { key: "profile", label: "Profile" },
  { key: "approvals", label: "Approvals" },
  { key: "audit", label: "Audit Log" },
] as const;

type NavKey = (typeof NAV_ITEMS)[number]["key"];

export const DeviceShell: React.FC<{
  active: NavKey;
  children: React.ReactNode;
}> = ({ active, children }) => {
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background:
          "radial-gradient(circle at 50% 45%, #4b4f57 0%, #232629 55%, #15171a 100%)",
      }}
    >
      <div
        style={{
          width: 1380,
          height: 860,
          borderRadius: 20,
          overflow: "hidden",
          display: "flex",
          boxShadow: "0 40px 90px rgba(0,0,0,0.55)",
          background: "#0b0e16",
        }}
      >
        <div
          style={{
            width: 320,
            background: "#10141f",
            display: "flex",
            flexDirection: "column",
            padding: 28,
            borderRight: "1px solid #1c2230",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div
              style={{
                width: 44,
                height: 44,
                borderRadius: 10,
                background: "#2f6fed",
                color: "white",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontWeight: 700,
                fontSize: 18,
              }}
            >
              OT
            </div>
            <div>
              <div style={{ color: "#f1f5f9", fontWeight: 700, fontSize: 20 }}>
                GOV-OS
              </div>
              <div style={{ color: "#64748b", fontSize: 13 }}>
                Secure Terminal
              </div>
            </div>
          </div>

          <div style={{ marginTop: 36, display: "flex", flexDirection: "column", gap: 6 }}>
            {NAV_ITEMS.map((item) => {
              const isActive = item.key === active;
              return (
                <div
                  key={item.key}
                  style={{
                    padding: "12px 16px",
                    borderRadius: 10,
                    fontSize: 16,
                    fontWeight: isActive ? 600 : 500,
                    color: isActive ? "#5b9bff" : "#8b93a3",
                    background: isActive ? "rgba(59,130,246,0.14)" : "transparent",
                  }}
                >
                  {item.label}
                </div>
              );
            })}
          </div>

          <div style={{ marginTop: "auto", display: "flex", flexDirection: "column", gap: 14 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <div
                style={{
                  width: 9,
                  height: 9,
                  borderRadius: 999,
                  background: "#22c55e",
                }}
              />
              <div>
                <div style={{ color: "#e5e7eb", fontWeight: 600, fontSize: 15 }}>
                  District Judge
                </div>
                <div style={{ color: "#64748b", fontSize: 12 }}>
                  Authorized session
                </div>
              </div>
            </div>
            <div
              style={{
                background: "rgba(244,63,94,0.12)",
                color: "#fb7185",
                textAlign: "center",
                padding: "10px 0",
                borderRadius: 8,
                fontSize: 14,
                fontWeight: 600,
              }}
            >
              Close ×
            </div>
          </div>
        </div>

        <div style={{ flex: 1, padding: 44, display: "flex", flexDirection: "column" }}>
          {children}
        </div>
      </div>
    </div>
  );
};
