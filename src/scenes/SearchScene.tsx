import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { DeviceShell } from "../components/DeviceShell";
import { Caption } from "../components/Caption";

const QUERY = "De Santa";

export const SearchScene: React.FC<{ durationInFrames: number }> = ({
  durationInFrames,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

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

  const typingStart = fps * 0.3;
  const typingSpeed = 2.4;
  const charsShown = Math.max(
    0,
    Math.min(QUERY.length, Math.floor((frame - typingStart) / typingSpeed)),
  );
  const typedText = QUERY.slice(0, charsShown);

  const resultOpacity = interpolate(
    frame,
    [typingStart + QUERY.length * typingSpeed + 4, typingStart + QUERY.length * typingSpeed + 16],
    [0, 1],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const resultY = interpolate(
    frame,
    [typingStart + QUERY.length * typingSpeed + 4, typingStart + QUERY.length * typingSpeed + 16],
    [16, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  const cursorBlink = Math.floor(frame / 15) % 2 === 0;

  return (
    <AbsoluteFill style={{ opacity: sceneFadeIn * sceneFadeOut }}>
      <DeviceShell active="search">
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 14,
            border: "1px solid #243044",
            background: "#0f1320",
            borderRadius: 12,
            padding: "18px 22px",
            boxShadow:
              charsShown > 0 ? "0 0 0 3px rgba(47,111,237,0.25)" : "none",
          }}
        >
          <span style={{ color: "#5b9bff", fontSize: 22 }}>⌕</span>
          <span
            style={{
              color: "#e5e7eb",
              fontSize: 24,
              fontFamily:
                '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
            }}
          >
            {typedText}
            <span style={{ opacity: cursorBlink ? 1 : 0 }}>|</span>
          </span>
        </div>

        <div
          style={{
            marginTop: 26,
            opacity: resultOpacity,
            transform: `translateY(${resultY}px)`,
            display: "flex",
            alignItems: "center",
            gap: 18,
            background: "#0f1320",
            border: "1px solid #1c2230",
            borderRadius: 12,
            padding: 18,
          }}
        >
          <div
            style={{
              width: 52,
              height: 52,
              borderRadius: 999,
              background: "#1c2230",
            }}
          />
          <div>
            <div style={{ color: "#f1f5f9", fontWeight: 700, fontSize: 22 }}>
              Michael De Santa
            </div>
            <div style={{ color: "#64748b", fontSize: 15, marginTop: 2 }}>
              Citizen ID: ABC12345 &nbsp;·&nbsp; Phone: 555-0147
            </div>
          </div>
        </div>
      </DeviceShell>
      <Caption
        text="Search any citizen instantly — by name, citizen ID, phone number, or plate."
        durationInFrames={durationInFrames}
      />
    </AbsoluteFill>
  );
};
