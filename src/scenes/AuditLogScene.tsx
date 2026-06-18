import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { DeviceShell } from "../components/DeviceShell";
import { Caption } from "../components/Caption";

const ROWS = [
  { time: "14:32", who: "District Judge T. Okafor", action: "Approved fund seizure — Crypto Wallet ($32,000)" },
  { time: "14:21", who: "Officer J. Reyes", action: "Flagged vehicle BFRM5521 for seizure" },
  { time: "13:58", who: "Officer K. Lindt", action: "Added conviction: Armed Robbery, Assault on Officer" },
  { time: "13:40", who: "Officer M. Tran", action: "Issued fine: Reckless Driving ($2,500)" },
];

export const AuditLogScene: React.FC<{ durationInFrames: number }> = ({
  durationInFrames,
}) => {
  const frame = useCurrentFrame();

  const sceneFadeIn = interpolate(frame, [0, 10], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const sceneFadeOut = interpolate(
    frame,
    [durationInFrames - 14, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill style={{ opacity: sceneFadeIn * sceneFadeOut }}>
      <DeviceShell active="audit">
        <div
          style={{
            color: "#f1f5f9",
            fontSize: 30,
            fontWeight: 700,
            fontFamily:
              '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
          }}
        >
          Audit Log
        </div>

        <div style={{ marginTop: 26, display: "flex", flexDirection: "column", gap: 14 }}>
          {ROWS.map((row, i) => {
            const start = 10 + i * 10;
            const opacity = interpolate(frame, [start, start + 12], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            const x = interpolate(frame, [start, start + 12], [-16, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            return (
              <div
                key={row.time + i}
                style={{
                  opacity,
                  transform: `translateX(${x}px)`,
                  display: "flex",
                  gap: 18,
                  alignItems: "baseline",
                  background: "#0f1320",
                  border: "1px solid #1c2230",
                  borderRadius: 10,
                  padding: "14px 18px",
                }}
              >
                <div style={{ color: "#5b9bff", fontSize: 15, fontWeight: 700, width: 60 }}>
                  {row.time}
                </div>
                <div>
                  <div style={{ color: "#f1f5f9", fontSize: 16, fontWeight: 600 }}>
                    {row.who}
                  </div>
                  <div style={{ color: "#64748b", fontSize: 14, marginTop: 2 }}>
                    {row.action}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </DeviceShell>
      <Caption
        text="Every action. Every staff member. Fully logged — nothing happens off the record."
        durationInFrames={durationInFrames}
      />
    </AbsoluteFill>
  );
};
