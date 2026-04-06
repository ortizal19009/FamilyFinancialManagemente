import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { AuthService, User } from '../../services/auth.service';

@Component({
  selector: 'app-admin-users',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './admin-users.html',
  styleUrl: './admin-users.scss'
})
export class AdminUsersComponent implements OnInit {
  private authService = inject(AuthService);

  users: User[] = [];
  newUser = {
    full_name: '',
    email: '',
    password: '',
    role: 'member'
  };

  loading = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadUsers();
  }

  loadUsers() {
    this.authService.getUsers().subscribe({
      next: (data) => this.users = data,
      error: () => this.errorMsg = 'No tienes permisos de administrador'
    });
  }

  onCreateUser() {
    this.loading = true;
    this.authService.adminCreateUser(this.newUser).subscribe({
      next: () => {
        this.successMsg = 'Usuario creado correctamente';
        this.newUser = { full_name: '', email: '', password: '', role: 'member' };
        this.loadUsers();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (err) => {
        this.errorMsg = err.error?.msg || 'Error al crear el usuario';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }
}
