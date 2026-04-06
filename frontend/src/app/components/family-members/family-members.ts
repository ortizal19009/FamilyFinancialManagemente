import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-family-members',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './family-members.html',
  styleUrl: './family-members.scss'
})
export class FamilyMembersComponent implements OnInit {
  private apiService = inject(ApiService);

  members: any[] = [];
  formMember = this.createEmptyMember();

  editingMember: any = null;
  loading = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadMembers();
  }

  loadMembers() {
    this.apiService.getFamilyMembers().subscribe(data => this.members = data);
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
      relationship: member.relationship
    };
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
      relationship: 'Yo'
    };
  }
}
