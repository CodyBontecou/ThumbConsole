import React from 'react';
import {Composition} from 'remotion';
import {ThumbleLaunch} from './ThumbleLaunch';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="ThumbleLaunch"
      component={ThumbleLaunch}
      durationInFrames={45 * 30}
      fps={30}
      width={3840}
      height={2160}
    />
  );
};
