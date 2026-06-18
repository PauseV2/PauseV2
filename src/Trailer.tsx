import React from "react";
import { AbsoluteFill, Series, staticFile } from "remotion";
import { TitleCard } from "./scenes/TitleCard";
import { SearchScene } from "./scenes/SearchScene";
import { ImageScene } from "./scenes/ImageScene";
import { ApprovalsScene } from "./scenes/ApprovalsScene";
import { AuditLogScene } from "./scenes/AuditLogScene";
import { OutroCard } from "./scenes/OutroCard";

const TITLE = 120;
const SEARCH = 180;
const PROFILE = 180;
const FINANCIAL = 180;
const VEHICLES = 270;
const PROPERTIES = 180;
const CRIMINAL = 180;
const APPROVALS = 210;
const AUDIT = 150;
const OUTRO = 150;

export const Trailer: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "black" }}>
      <Series>
        <Series.Sequence durationInFrames={TITLE}>
          <TitleCard durationInFrames={TITLE} />
        </Series.Sequence>

        <Series.Sequence durationInFrames={SEARCH}>
          <SearchScene durationInFrames={SEARCH} />
        </Series.Sequence>

        <Series.Sequence durationInFrames={PROFILE}>
          <ImageScene
            src={staticFile("images/profile-overview.png")}
            caption="Pull up their full file — identity, finances, vehicles, properties, and criminal record — all in one secure terminal."
            durationInFrames={PROFILE}
            pan="right"
          />
        </Series.Sequence>

        <Series.Sequence durationInFrames={FINANCIAL}>
          <ImageScene
            src={staticFile("images/financial.png")}
            caption="Freeze accounts, hide funds, or seize them outright — every action checked and logged, server-side, every time."
            durationInFrames={FINANCIAL}
            pan="left"
          />
        </Series.Sequence>

        <Series.Sequence durationInFrames={VEHICLES}>
          <ImageScene
            src={staticFile("images/vehicles.png")}
            caption="Flag a vehicle for seizure, with a reason on record — it stays exactly where it is, until your police actually find it and bring it in."
            durationInFrames={VEHICLES}
            pan="right"
          />
        </Series.Sequence>

        <Series.Sequence durationInFrames={PROPERTIES}>
          <ImageScene
            src={staticFile("images/properties.png")}
            caption="Seize property when you need to. Restore it with one click — nothing is ever permanent unless you want it to be."
            durationInFrames={PROPERTIES}
            pan="left"
          />
        </Series.Sequence>

        <Series.Sequence durationInFrames={CRIMINAL}>
          <ImageScene
            src={staticFile("images/criminal-record.png")}
            caption="Add convictions straight from the tablet, synced with your MDT and booking system."
            durationInFrames={CRIMINAL}
            pan="right"
          />
        </Series.Sequence>

        <Series.Sequence durationInFrames={APPROVALS}>
          <ApprovalsScene durationInFrames={APPROVALS} />
        </Series.Sequence>

        <Series.Sequence durationInFrames={AUDIT}>
          <AuditLogScene durationInFrames={AUDIT} />
        </Series.Sequence>

        <Series.Sequence durationInFrames={OUTRO}>
          <OutroCard durationInFrames={OUTRO} />
        </Series.Sequence>
      </Series>
    </AbsoluteFill>
  );
};

export const TRAILER_DURATION =
  TITLE + SEARCH + PROFILE + FINANCIAL + VEHICLES + PROPERTIES + CRIMINAL + APPROVALS + AUDIT + OUTRO;
