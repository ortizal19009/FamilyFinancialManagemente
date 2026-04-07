import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { AuthService, User } from '../../services/auth.service';

@Component({
  selector: 'app-family-members',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './family-members.html',
  styleUrl: './family-members.scss'
})
export class FamilyMembersComponent implements OnInit {
  private apiService = inject(ApiService);
  private authService = inject(AuthService);

  members: any[] = [];
  linkableUsers: User[] = [];
  formMember = this.createEmptyMember();

  editingMember: any = null;
  loading = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadLinkableUsers();
    this.loadMembers();
  }

  loadMembers() {
    this.apiService.getFamilyMembers().subscribe(data => this.members = data);
  }

  loadLinkableUsers() {
    this.authService.getFamilyLinkOptions().subscribe({
      next: (users) => {
        this.linkableUsers = users;
      },
    });
  }

  onCreateMember() {
    this.loading = true;
    this.apiService.createFamilyMember(this.formMember).subscribe({
      next: () => {
        this.successMsg = 'Miembro agregado';
        this.resetForm();
        this.loadMembers();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al agregar';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEdit(member: any) {
    this.editingMember = { ...member };
    this.formMember = {
      name: member.name,
      relationship: member.relationship,
      linked_user_email: member.linked_user_email ?? ''
    };
  }

  onLinkedUserChange() {
    const selectedUser = this.linkableUsers.find(
      (user) => user.email === this.formMember.linked_user_email,
    );
    if (!selectedUser) {
      return;
    }

    this.formMember.name = selectedUser.full_name;
  }

  onUpdateMember() {
    this.loading = true;
    this.apiService.updateFamilyMember(this.editingMember.id, this.formMember).subscribe({
      next: () => {
        this.successMsg = 'Actualizado correctamente';
        this.resetForm();
        this.loadMembers();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al actualizar';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onDelete(id: number) {
    if (confirm('¿Estás seguro de eliminar este miembro?')) {
      this.apiService.deleteFamilyMember(id).subscribe(() => this.loadMembers());
    }
  }

  onCancelEdit() {
    this.resetForm();
  }

  private resetForm() {
    this.editingMember = null;
    this.formMember = this.createEmptyMember();
  }

  private createEmptyMember() {
    return {
      name: '',
      relationship: 'Esposa',
      linked_user_email: ''
    };
  }
}
