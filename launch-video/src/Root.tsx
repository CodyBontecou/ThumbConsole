import React from 'react';
import {Composition} from 'remotion';
import {ThumbConsoleLaunch} from './ThumbConsoleLaunch';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="ThumbConsoleLaunch"
      component={ThumbConsoleLaunch}
      durationInFrames={45 * 30}
      fps={30}
      width={3840}
      height={2160}
    />
  );
};
