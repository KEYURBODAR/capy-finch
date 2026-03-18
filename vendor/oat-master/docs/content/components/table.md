+++
title = "Table"
weight = 140
description = "Data tables with thead, tbody. Styled automatically."
+++

Tables are styled by default. Use `<thead>` and `<tbody>` tags. Wrap in a `class="table"` container to get a horizontal scrollbar on small screens.

{% demo() %}
```html
<div class="table">
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>Role</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Alice Johnson</td>
        <td>alice@example.com</td>
        <td>Admin</td>
        <td><span class="badge success">Active</span></td>
      </tr>
      <tr>
        <td>Bob Smith</td>
        <td>bob@example.com</td>
        <td>Editor</td>
        <td><span class="badge">Active</span></td>
      </tr>
      <tr>
        <td>Carol White</td>
        <td>carol@example.com</td>
        <td>Viewer</td>
        <td><span class="badge secondary">Pending</span></td>
      </tr>
    </tbody>
  </table>
</div>
```
{% end %}
