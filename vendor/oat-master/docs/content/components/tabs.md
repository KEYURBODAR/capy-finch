+++
title = "Tabs"
weight = 150
description = "Tabbed interface using a custom WebComponent and semantic behaviour."

[extra]
webcomponent = true
+++

Wrap tab buttons and panels in `<ot-tabs>`. Use `role="tablist"`, `role="tab"`, and `role="tabpanel"`.

{% demo() %}
```html
<ot-tabs>
  <div role="tablist">
    <button role="tab">Account</button>
    <button role="tab">Password</button>
    <button role="tab">Notifications</button>
  </div>
  <div role="tabpanel">
    <h3>Account Settings</h3>
    <p>Manage your account information here.</p>
  </div>
  <div role="tabpanel">
    <h3>Password Settings</h3>
    <p>Change your password here.</p>
  </div>
  <div role="tabpanel">
    <h3>Notification Settings</h3>
    <p>Configure your notification preferences.</p>
  </div>
</ot-tabs>
```
{% end %}
