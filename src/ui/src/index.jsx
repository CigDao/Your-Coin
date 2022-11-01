import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './app';
import {HashRouter} from "react-router-dom";
import "bootstrap/dist/css/bootstrap.css";
import "bootstrap/dist/js/bootstrap";
import "jquery/dist/jquery";
import "@popperjs/core/dist/cjs/popper";
import "./background.scss";
import "./bootstrap-overrides.scss";

import {
  RecoilRoot
} from 'recoil';

const container = document.getElementById('root');
const root = createRoot(container)
root.render(
    <RecoilRoot>
      <HashRouter>
        <App />
      </HashRouter>
    </RecoilRoot>
);