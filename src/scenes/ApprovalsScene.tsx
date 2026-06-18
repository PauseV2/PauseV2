import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { DeviceShell } from "../components/DeviceShell";
import { Caption } from "../components/Caption";

export const ApprovalsScene: React.FC<{ durationInFrames: number }> = ({
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

  const cardOpacity = interpolate(frame, [12, 26], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const cardY = interpolate(frame, [12, 26], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const pingScale = interpolate(frame % 40, [0, 20, 40], [1, 1.25, 1]);

  return (
    <AbsoluteFill style={{ opacity: sceneFadeIn * sceneFadeOut }}>
      <DeviceShell active="approvals">
        <div
          style={{
            color: "#f1f5f9",
            fontSize: 30,
            fontWeight: 700,
            fontFamily:
              '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
            display: "flex",
            alignItems: "center",
            gap: 12,
          }}
        >
          Approvals Queue
          <span
            style={{
              width: 12,
              height: 12,
              borderRadius: 999,
              background: "#f59e0b",
              transform: `scale(${pingScale})`,
            }}
          />
        </div>

        <div
          style={{
            marginTop: 30,
            opacity: cardOpacity,
            transform: `translateY(${cardY}px)`,
            background: "#0f1320",
            border: "1px solid #1c2230",
            borderRadius: 14,
            padding: 26,
          }}
        >
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div>
              <div style={{ color: "#f1f5f9", fontWeight: 700, fontSize: 22 }}>
                Fund Seizure Request
              </div>
              <div style={{ color: "#64748b", fontSize: 15, marginTop: 6 }}>
                Requested by Officer J. Reyes &nbsp;·&nbsp; Target: Michael De Santa
              </div>
              <div style={{ color: "#94a3b8", fontSize: 17, marginTop: 14 }}>
                Crypto Wallet &nbsp;—&nbsp; <span style={{ color: "#f1f5f9", fontWeight: 700 }}>$32,000</span>
              </div>
            </div>
            <div
              style={{
                background: "rgba(245,158,11,0.14)",
                color: "#f59e0b",
                fontSize: 13,
                fontWeight: 700,
                padding: "6px 12px",
                borderRadius: 999,
              }}
            >
              PENDING
            </div>
          </div>

          <div style={{ display: "flex", gap: 14, marginTop: 24 }}>
            <div
              style={{
                background: "rgba(34,197,94,0.14)",
                color: "#4ade80",
                fontWeight: 700,
                fontSize: 16,
                padding: "10px 22px",
                borderRadius: 8,
              }}
            >
              Approve
            </div>
            <div
              style={{
                background: "rgba(244,63,94,0.14)",
                color: "#fb7185",
                fontWeight: 700,
                fontSize: 16,
                padding: "10px 22px",
                borderRadius: 8,
              }}
            >
              Deny
            </div>
          </div>
        </div>
      </DeviceShell>
      <Caption
        text="Big seizures get a second opinion. Judges review and approve, right from their own terminal."
        durationInFrames={durationInFrames}
      />
    </AbsoluteFill>
  );
};
